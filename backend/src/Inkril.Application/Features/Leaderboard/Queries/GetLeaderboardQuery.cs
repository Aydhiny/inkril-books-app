using Inkril.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace Inkril.Application.Features.Leaderboard.Queries;

public record LeaderboardEntryDto(
    int Rank, Guid UserId, string UserName, string? ProfilePhotoUrl,
    int TotalMinutesRead, int CurrentStreak, int BooksCompleted);

public record GetLeaderboardQuery(Guid RequestingUserId, int Top = 20) : IRequest<LeaderboardResult>;

public record LeaderboardResult(
    IEnumerable<LeaderboardEntryDto> Entries,
    LeaderboardEntryDto? CurrentUserEntry);

public class GetLeaderboardQueryHandler(IUnitOfWork uow, IMemoryCache cache)
    : IRequestHandler<GetLeaderboardQuery, LeaderboardResult>
{
    // Cap client-supplied Top so a single request cannot force the server to
    // serialize an arbitrarily large list. 100 entries is more than any UI needs.
    private const int MaxTop = 100;

    // The ranked entries list is identical for every user — only the
    // highlighted "currentUserEntry" differs. Cache the shared list for 60 s
    // so the expensive GROUP BY aggregate runs at most once per minute.
    private static readonly object _entriesCacheKey = new();

    public async Task<LeaderboardResult> Handle(GetLeaderboardQuery q, CancellationToken ct)
    {
        var entries = await cache.GetOrCreateAsync<List<LeaderboardEntryDto>>(
            _entriesCacheKey,
            async ce =>
            {
                ce.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(60);

                // Global leaderboard — show all users so it's populated even for new accounts.
                var stats = await uow.DailyReadingStats.Query()
                    .Where(s => !s.IsDeleted)
                    .GroupBy(s => new { s.UserId, s.User.UserName, s.User.ProfilePhotoUrl })
                    .Select(g => new
                    {
                        g.Key.UserId,
                        g.Key.UserName,
                        g.Key.ProfilePhotoUrl,
                        TotalMinutes = g.Sum(s => s.MinutesRead),
                        BooksCompleted = g.Sum(s => s.BooksCompleted),
                        CurrentStreak = g.Max(s => s.StreakDays)
                    })
                    .OrderByDescending(s => s.TotalMinutes)
                    .ToListAsync(ct);

                return stats.Select((s, i) => new LeaderboardEntryDto(
                    i + 1, s.UserId, s.UserName!, s.ProfilePhotoUrl,
                    s.TotalMinutes, s.CurrentStreak, s.BooksCompleted)).ToList();
            }) ?? [];

        // currentUserEntry is personalized — resolved from the cached list in O(n).
        var currentUserEntry = entries.FirstOrDefault(e => e.UserId == q.RequestingUserId);
        var top = entries.Take(Math.Min(q.Top, MaxTop)).ToList();

        return new LeaderboardResult(top, currentUserEntry);
    }
}
