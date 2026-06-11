using Inkril.Application.Common.Interfaces;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Reports.Queries;

public record DashboardStatsDto(
    int TotalUsers,
    int ActiveUsersLast7Days,
    double AverageReadingHoursPerUser,
    int TotalBooksRead,
    int TotalBooks,
    int CompletedBooksCount,
    int InProgressBooksCount,
    IEnumerable<DailyActivityDto> Last14DaysActivity,
    int TotalReadingSessions,
    double AverageSessionMinutes,
    IEnumerable<TopBookDto> TopBooks,
    IEnumerable<TopReaderDto> TopReaders,
    IEnumerable<GenreCountDto> GenreDistribution);

public record DailyActivityDto(DateOnly Date, int ActiveUsers, int SessionCount, int MinutesRead);
public record TopBookDto(string Title, int ReaderCount);
public record TopReaderDto(string UserName, int TotalMinutes);
public record GenreCountDto(string Name, int Count);

/// <param name="Days">Window for the activity chart. Defaults to 14.</param>
public record GetDashboardStatsQuery(int Days = 14) : IRequest<DashboardStatsDto>;

public class GetDashboardStatsQueryHandler(IUnitOfWork uow, UserManager<ApplicationUser> userManager)
    : IRequestHandler<GetDashboardStatsQuery, DashboardStatsDto>
{
    public async Task<DashboardStatsDto> Handle(GetDashboardStatsQuery q, CancellationToken ct)
    {
        var activeCutoff = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-7));
        var chartCutoff  = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-q.Days));

        // ── Core KPIs ─────────────────────────────────────────────────────────────────
        var totalUsers = await userManager.Users.CountAsync(u => !u.IsDeleted, ct);

        var activeUsers = await uow.DailyReadingStats.Query()
            .Where(s => s.Date >= activeCutoff)
            .Select(s => s.UserId).Distinct().CountAsync(ct);

        var totalMinutes   = await uow.DailyReadingStats.Query().SumAsync(s => s.MinutesRead, ct);
        var totalBooksRead = await uow.DailyReadingStats.Query().SumAsync(s => s.BooksCompleted, ct);
        var totalBooks     = await uow.Books.CountAsync(b => !b.IsDeleted, ct);
        var avgHours       = totalUsers > 0 ? (double)totalMinutes / 60 / totalUsers : 0;

        var completedBooks  = await uow.UserBooks.CountAsync(b => !b.IsDeleted && b.IsCompleted, ct);
        var inProgressBooks = await uow.UserBooks.CountAsync(
            b => !b.IsDeleted && !b.IsCompleted && b.ReadingProgressPercent > 0, ct);

        // ── Activity chart ────────────────────────────────────────────────────────────
        // Fetch raw rows then group client-side: Npgsql can't translate
        // Distinct().Count() inside a server-side GroupBy projection.
        var rawActivity = await uow.DailyReadingStats.Query()
            .Where(s => s.Date >= chartCutoff)
            .Select(s => new { s.Date, s.UserId, s.MinutesRead })
            .ToListAsync(ct);

        var activityWindow = rawActivity
            .GroupBy(s => s.Date)
            .Select(g => new DailyActivityDto(
                g.Key,
                g.Select(s => s.UserId).Distinct().Count(),
                g.Count(),
                g.Sum(s => s.MinutesRead)))
            .OrderBy(d => d.Date)
            .ToList();

        // ── Reading sessions ──────────────────────────────────────────────────────────
        var completedSessions = uow.ReadingSessions.Query()
            .Where(s => !s.IsDeleted && s.EndedAt != null);

        var totalSessions = await completedSessions.CountAsync(ct);
        var avgSessionMins = totalSessions > 0
            ? await completedSessions.AverageAsync(s => (double)s.DurationMinutes, ct)
            : 0.0;

        // ── Top books by unique reader count ─────────────────────────────────────────
        var topBooksRaw = await uow.UserBooks.Query()
            .Where(ub => !ub.IsDeleted)
            .GroupBy(ub => ub.BookId)
            .Select(g => new { BookId = g.Key, ReaderCount = g.Count() })
            .OrderByDescending(x => x.ReaderCount)
            .Take(10)
            .ToListAsync(ct);

        var topBookIds = topBooksRaw.Select(x => x.BookId).ToList();
        var bookTitles = await uow.Books.Query()
            .Where(b => topBookIds.Contains(b.Id) && !b.IsDeleted)
            .Select(b => new { b.Id, b.Title })
            .ToListAsync(ct);

        var topBooks = topBooksRaw
            .Select(x => new TopBookDto(
                bookTitles.FirstOrDefault(b => b.Id == x.BookId)?.Title ?? "Unknown",
                x.ReaderCount))
            .ToList();

        // ── Top readers by total minutes ──────────────────────────────────────────────
        // Group first server-side, then resolve usernames via a second query using the
        // User navigation property (DailyReadingStat.User is a required nav).
        var topReadersSums = await uow.DailyReadingStats.Query()
            .GroupBy(s => s.UserId)
            .Select(g => new { UserId = g.Key, TotalMinutes = g.Sum(s => s.MinutesRead) })
            .OrderByDescending(x => x.TotalMinutes)
            .Take(10)
            .ToListAsync(ct);

        var readerIds = topReadersSums.Select(r => r.UserId).ToList();
        var readerNames = await uow.DailyReadingStats.Query()
            .Include(s => s.User)
            .Where(s => readerIds.Contains(s.UserId))
            .Select(s => new { s.UserId, s.User.UserName })
            .Distinct()
            .ToListAsync(ct);

        var topReaders = topReadersSums
            .Select(r => new TopReaderDto(
                readerNames.FirstOrDefault(u => u.UserId == r.UserId)?.UserName ?? r.UserId.ToString()[..8],
                r.TotalMinutes))
            .ToList();

        // ── Genre distribution ────────────────────────────────────────────────────────
        // Two-step: fetch FK IDs server-side (EF can translate scalar selects), then
        // join with genre names in memory. Server-side GroupBy on a navigation property
        // (bg.Genre.Name) fails because EF Core can't produce the implicit JOIN in
        // a GroupBy projection without an explicit Include.
        var bookGenreIds = await uow.Books.Query()
            .Where(b => !b.IsDeleted)
            .SelectMany(b => b.BookGenres.Select(bg => bg.GenreId))
            .ToListAsync(ct);

        var allGenres = await uow.Genres.Query()
            .Select(g => new { g.Id, g.Name })
            .ToListAsync(ct);

        var genreDistribution = bookGenreIds
            .GroupBy(id => id)
            .Select(g => new GenreCountDto(
                allGenres.FirstOrDefault(ag => ag.Id == g.Key)?.Name ?? "Unknown",
                g.Count()))
            .Where(x => x.Name != "Unknown")
            .OrderByDescending(x => x.Count)
            .Take(8)
            .ToList();

        return new DashboardStatsDto(
            totalUsers, activeUsers, avgHours, totalBooksRead, totalBooks,
            completedBooks, inProgressBooks, activityWindow,
            totalSessions, avgSessionMins, topBooks, topReaders, genreDistribution);
    }
}
