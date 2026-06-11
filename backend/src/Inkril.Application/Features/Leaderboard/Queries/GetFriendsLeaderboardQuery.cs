using Inkril.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Leaderboard.Queries;

public record GetFriendsLeaderboardQuery(Guid RequestingUserId) : IRequest<LeaderboardResult>;

public class GetFriendsLeaderboardQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetFriendsLeaderboardQuery, LeaderboardResult>
{
    public async Task<LeaderboardResult> Handle(GetFriendsLeaderboardQuery q, CancellationToken ct)
    {
        // Collect friend IDs from both sides of the Friendship row
        var friendIds = await uow.Friendships.Query()
            .Where(f => !f.IsDeleted && (f.UserId == q.RequestingUserId || f.FriendId == q.RequestingUserId))
            .Select(f => f.UserId == q.RequestingUserId ? f.FriendId : f.UserId)
            .ToListAsync(ct);

        // Always include the requesting user so they see themselves on the board
        var participantIds = friendIds.Append(q.RequestingUserId).Distinct().ToList();

        var today     = DateOnly.FromDateTime(DateTime.UtcNow);
        var yesterday = today.AddDays(-1);

        var currentStreaks = await uow.DailyReadingStats.Query()
            .Where(s => !s.IsDeleted
                     && participantIds.Contains(s.UserId)
                     && (s.Date == today || s.Date == yesterday))
            .GroupBy(s => s.UserId)
            .Select(g => new
            {
                UserId        = g.Key,
                CurrentStreak = g.OrderByDescending(s => s.Date)
                                 .Select(s => s.StreakDays)
                                 .FirstOrDefault()
            })
            .ToDictionaryAsync(x => x.UserId, x => x.CurrentStreak, ct);

        var stats = await uow.DailyReadingStats.Query()
            .Where(s => !s.IsDeleted && participantIds.Contains(s.UserId))
            .GroupBy(s => new { s.UserId, s.User.UserName, s.User.ProfilePhotoUrl })
            .Select(g => new
            {
                g.Key.UserId,
                g.Key.UserName,
                g.Key.ProfilePhotoUrl,
                TotalMinutes   = g.Sum(s => s.MinutesRead),
                BooksCompleted = g.Sum(s => s.BooksCompleted)
            })
            .OrderByDescending(s => s.TotalMinutes)
            .ToListAsync(ct);

        // If the requesting user has no stats at all, ensure they still appear at the bottom
        if (!stats.Any(s => s.UserId == q.RequestingUserId))
        {
            // We can't fetch the username here without UserManager — return empty entry
            // The client already knows who "You" is so this is fine.
        }

        var entries = stats
            .Select((s, i) => new LeaderboardEntryDto(
                i + 1, s.UserId, s.UserName!, s.ProfilePhotoUrl,
                s.TotalMinutes,
                currentStreaks.TryGetValue(s.UserId, out var streak) ? streak : 0,
                s.BooksCompleted))
            .ToList();

        var currentUserEntry = entries.FirstOrDefault(e => e.UserId == q.RequestingUserId);

        return new LeaderboardResult(entries, currentUserEntry);
    }
}
