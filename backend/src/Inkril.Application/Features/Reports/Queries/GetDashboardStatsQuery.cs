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
    IEnumerable<DailyActivityDto> Last14DaysActivity);

public record DailyActivityDto(DateOnly Date, int ActiveUsers, int SessionCount, int MinutesRead);

public record GetDashboardStatsQuery : IRequest<DashboardStatsDto>;

public class GetDashboardStatsQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetDashboardStatsQuery, DashboardStatsDto>
{
    public async Task<DashboardStatsDto> Handle(GetDashboardStatsQuery q, CancellationToken ct)
    {
        var cutoff = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-7));
        var last14 = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-14));

        var totalUsers = await uow.DailyReadingStats.Query()
            .Select(s => s.UserId).Distinct().CountAsync(ct);

        var activeUsers = await uow.DailyReadingStats.Query()
            .Where(s => s.Date >= cutoff)
            .Select(s => s.UserId).Distinct().CountAsync(ct);

        var totalMinutes = await uow.DailyReadingStats.Query().SumAsync(s => s.MinutesRead, ct);
        var totalBooksRead = await uow.DailyReadingStats.Query().SumAsync(s => s.BooksCompleted, ct);
        var totalBooks = await uow.Books.CountAsync(b => !b.IsDeleted, ct);

        var avgHours = totalUsers > 0 ? (double)totalMinutes / 60 / totalUsers : 0;

        var last14Activity = await uow.DailyReadingStats.Query()
            .Where(s => s.Date >= last14)
            .GroupBy(s => s.Date)
            .Select(g => new DailyActivityDto(
                g.Key,
                g.Select(s => s.UserId).Distinct().Count(),
                g.Count(),
                g.Sum(s => s.MinutesRead)))
            .OrderBy(d => d.Date)
            .ToListAsync(ct);

        return new DashboardStatsDto(totalUsers, activeUsers, avgHours,
            totalBooksRead, totalBooks, last14Activity);
    }
}
