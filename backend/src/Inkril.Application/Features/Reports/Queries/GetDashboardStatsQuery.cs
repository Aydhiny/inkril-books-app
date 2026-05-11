using Inkril.Application.Common.Interfaces;
using MediatR;
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
    IEnumerable<DailyActivityDto> Last14DaysActivity);

public record DailyActivityDto(DateOnly Date, int ActiveUsers, int SessionCount, int MinutesRead);

/// <param name="Days">Window for the activity chart (7, 14, or 30 days). Defaults to 14.</param>
public record GetDashboardStatsQuery(int Days = 14) : IRequest<DashboardStatsDto>;

public class GetDashboardStatsQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetDashboardStatsQuery, DashboardStatsDto>
{
    public async Task<DashboardStatsDto> Handle(GetDashboardStatsQuery q, CancellationToken ct)
    {
        var activeCutoff  = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-7));
        var chartCutoff   = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-q.Days));

        var totalUsers = await uow.DailyReadingStats.Query()
            .Select(s => s.UserId).Distinct().CountAsync(ct);

        var activeUsers = await uow.DailyReadingStats.Query()
            .Where(s => s.Date >= activeCutoff)
            .Select(s => s.UserId).Distinct().CountAsync(ct);

        var totalMinutes  = await uow.DailyReadingStats.Query().SumAsync(s => s.MinutesRead, ct);
        var totalBooksRead = await uow.DailyReadingStats.Query().SumAsync(s => s.BooksCompleted, ct);
        var totalBooks    = await uow.Books.CountAsync(b => !b.IsDeleted, ct);

        var avgHours = totalUsers > 0 ? (double)totalMinutes / 60 / totalUsers : 0;

        // Reading status breakdown for pie chart
        var completedBooks  = await uow.UserBooks.CountAsync(b => !b.IsDeleted && b.IsCompleted, ct);
        var inProgressBooks = await uow.UserBooks.CountAsync(
            b => !b.IsDeleted && !b.IsCompleted && b.ReadingProgressPercent > 0, ct);

        var activityWindow = await uow.DailyReadingStats.Query()
            .Where(s => s.Date >= chartCutoff)
            .GroupBy(s => s.Date)
            .Select(g => new DailyActivityDto(
                g.Key,
                g.Select(s => s.UserId).Distinct().Count(),
                g.Count(),
                g.Sum(s => s.MinutesRead)))
            .OrderBy(d => d.Date)
            .ToListAsync(ct);

        return new DashboardStatsDto(totalUsers, activeUsers, avgHours,
            totalBooksRead, totalBooks, completedBooks, inProgressBooks, activityWindow);
    }
}
