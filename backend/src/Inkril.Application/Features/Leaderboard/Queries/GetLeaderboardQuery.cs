using Inkril.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Leaderboard.Queries;

public record LeaderboardEntryDto(
    int Rank, Guid UserId, string UserName, string? ProfilePhotoUrl,
    int TotalMinutesRead, int CurrentStreak, int BooksCompleted);

public record GetLeaderboardQuery(Guid RequestingUserId, int Top = 20) : IRequest<LeaderboardResult>;

public record LeaderboardResult(
    IEnumerable<LeaderboardEntryDto> Entries,
    LeaderboardEntryDto? CurrentUserEntry);

public class GetLeaderboardQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetLeaderboardQuery, LeaderboardResult>
{
    public async Task<LeaderboardResult> Handle(GetLeaderboardQuery q, CancellationToken ct)
    {
        // Get friend IDs first — leaderboard is friends-only
        var friendIds = await uow.Friendships.Query()
            .Where(f => f.UserId == q.RequestingUserId || f.FriendId == q.RequestingUserId)
            .Select(f => f.UserId == q.RequestingUserId ? f.FriendId : f.UserId)
            .ToListAsync(ct);

        // Include requesting user themselves
        var participantIds = friendIds.Append(q.RequestingUserId).Distinct().ToList();

        var stats = await uow.DailyReadingStats.Query()
            .Where(s => participantIds.Contains(s.UserId) && !s.IsDeleted)
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

        var entries = stats.Select((s, i) => new LeaderboardEntryDto(
            i + 1, s.UserId, s.UserName!, s.ProfilePhotoUrl,
            s.TotalMinutes, s.CurrentStreak, s.BooksCompleted)).ToList();

        var currentUserEntry = entries.FirstOrDefault(e => e.UserId == q.RequestingUserId);
        var top = entries.Take(q.Top).ToList();

        return new LeaderboardResult(top, currentUserEntry);
    }
}
