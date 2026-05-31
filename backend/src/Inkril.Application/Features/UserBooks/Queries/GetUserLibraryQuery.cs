using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.UserBooks.Queries;

public record UserLibraryBookDto(
    Guid UserBookId,
    Guid BookId,
    string Title,
    string Author,
    string? CoverImageUrl,
    double ReadingProgressPercent,
    DateTime? LastReadAt,
    bool IsCompleted,
    int TotalPages,
    /// <summary>Average pages the user reads per minute, computed from all completed sessions.</summary>
    double AvgPagesPerMinute,
    /// <summary>Estimated minutes to finish the book at the user's average pace. Null when there is no session history.</summary>
    int? EstimatedMinutesRemaining,
    /// <summary>True when the book was imported from the user's local device storage.</summary>
    bool IsLocal);

public record GetUserLibraryQuery(Guid UserId, int PageNumber = 1, int PageSize = 20)
    : IRequest<PagedList<UserLibraryBookDto>>;

public class GetUserLibraryQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetUserLibraryQuery, PagedList<UserLibraryBookDto>>
{
    private const int MaxPageSize = 100;

    public async Task<PagedList<UserLibraryBookDto>> Handle(GetUserLibraryQuery q, CancellationToken ct)
    {
        var pageSize = Math.Min(q.PageSize, MaxPageSize);

        // ── Step 1: paginate the raw UserBook + Book rows ──────────────────
        var rawQuery = uow.UserBooks.Query()
            .Include(ub => ub.Book)
            .Where(ub => ub.UserId == q.UserId && !ub.Book.IsDeleted)
            .OrderByDescending(ub => ub.LastReadAt ?? ub.AddedAt);

        var totalCount = await rawQuery.CountAsync(ct);
        var items = await rawQuery
            .Skip((q.PageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(ub => new
            {
                ub.Id,
                ub.BookId,
                ub.Book.Title,
                ub.Book.Author,
                ub.Book.CoverImageUrl,
                ub.ReadingProgressPercent,
                ub.LastReadAt,
                ub.IsCompleted,
                ub.Book.TotalPages,
                ub.Book.IsLocal,
            })
            .ToListAsync(ct);

        // ── Step 2: aggregate reading speed per book from past sessions ────
        // Hits the (UserId, StartedAt) index added in AddHotPathIndexes migration.
        // Only completed sessions (EndedAt != null) with real duration are counted.
        //
        // NOTE: GroupBy + Sum is done in memory (not on the server) because EF Core /
        // Npgsql cannot translate the correlated GroupBy shape to SQL when the key
        // selector is a column that also appears in the WHERE clause (same issue as
        // GetDashboardStatsQuery). We project the three columns we need first, then
        // group in memory — identical technique to the dashboard fix.
        var bookIds = items.Select(x => x.BookId).ToList();
        var rawSessions = await uow.ReadingSessions.Query()
            .Where(rs => rs.UserId == q.UserId
                      && bookIds.Contains(rs.BookId)
                      && rs.EndedAt != null
                      && rs.DurationMinutes > 0)
            .Select(rs => new { rs.BookId, rs.PagesRead, rs.DurationMinutes })
            .ToListAsync(ct);

        var speedRows = rawSessions
            .GroupBy(rs => rs.BookId)
            .Select(g => new
            {
                BookId     = g.Key,
                TotalPages = g.Sum(rs => rs.PagesRead),
                TotalMins  = g.Sum(rs => rs.DurationMinutes)
            })
            .ToList();

        var speedMap = speedRows.ToDictionary(
            s => s.BookId,
            s => s.TotalMins > 0 ? (double)s.TotalPages / s.TotalMins : 0.0);

        // ── Step 3: build DTOs with ETA ───────────────────────────────────
        var dtos = items.Select(ub =>
        {
            speedMap.TryGetValue(ub.BookId, out var avgSpeed);
            int? eta = null;
            if (avgSpeed > 0 && ub.TotalPages > 0 && !ub.IsCompleted)
            {
                var pagesLeft = (int)Math.Ceiling(ub.TotalPages * (1 - ub.ReadingProgressPercent / 100.0));
                eta = (int)Math.Ceiling(pagesLeft / avgSpeed);
            }
            return new UserLibraryBookDto(
                ub.Id, ub.BookId, ub.Title, ub.Author, ub.CoverImageUrl,
                ub.ReadingProgressPercent, ub.LastReadAt, ub.IsCompleted,
                ub.TotalPages, Math.Round(avgSpeed, 2), eta, ub.IsLocal);
        }).ToList();

        return new PagedList<UserLibraryBookDto>(dtos, totalCount, q.PageNumber, pageSize);
    }
}
