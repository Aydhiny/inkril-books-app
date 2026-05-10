using Inkril.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.ActivityFeed;

// ── DTOs ──────────────────────────────────────────────────────────────────────

public record ActivityItemDto(
    string Type,           // "book_completed" | "milestone" | "review_written" | "streak"
    Guid UserId,
    string UserName,
    string? ProfilePhotoUrl,
    string BookTitle,
    string? BookCoverUrl,
    int? MilestonePercent, // for "milestone" type
    int? Rating,           // for "review_written"
    string? Comment,       // for "review_written"
    int? StreakDays,       // for "streak"
    DateTime Timestamp
);

// ── Query ─────────────────────────────────────────────────────────────────────

public record GetActivityFeedQuery : IRequest<IEnumerable<ActivityItemDto>>;

public class GetActivityFeedQueryHandler(
    IUnitOfWork uow,
    ICurrentUserService currentUser
) : IRequestHandler<GetActivityFeedQuery, IEnumerable<ActivityItemDto>>
{
    public async Task<IEnumerable<ActivityItemDto>> Handle(
        GetActivityFeedQuery _, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var since  = DateTime.UtcNow.AddDays(-14); // last 2 weeks

        // ── Get friend IDs ────────────────────────────────────────────────────
        var friendIds = await uow.Friendships.Query()
            .Where(f => f.UserId == userId)
            .Select(f => f.FriendId)
            .ToListAsync(ct);

        var reverseIds = await uow.Friendships.Query()
            .Where(f => f.FriendId == userId)
            .Select(f => f.UserId)
            .ToListAsync(ct);

        var allFriendIds = friendIds.Union(reverseIds).ToHashSet();

        if (allFriendIds.Count == 0)
            return [];

        var items = new List<ActivityItemDto>();

        // ── Books completed ───────────────────────────────────────────────────
        var completions = await uow.UserBooks.Query()
            .Include(ub => ub.User)
            .Include(ub => ub.Book)
            .Where(ub => allFriendIds.Contains(ub.UserId)
                      && ub.IsCompleted
                      && ub.CompletedAt.HasValue
                      && ub.CompletedAt >= since)
            .OrderByDescending(ub => ub.CompletedAt)
            .Take(30)
            .ToListAsync(ct);

        items.AddRange(completions.Select(ub => new ActivityItemDto(
            "book_completed",
            ub.UserId, ub.User.UserName!, ub.User.ProfilePhotoUrl,
            ub.Book.Title, ub.Book.CoverImageUrl,
            null, null, null, null,
            ub.CompletedAt!.Value)));

        // ── Reviews written ───────────────────────────────────────────────────
        var reviews = await uow.Reviews.Query()
            .Include(r => r.User)
            .Include(r => r.Book)
            .Where(r => allFriendIds.Contains(r.UserId) && r.CreatedAt >= since)
            .OrderByDescending(r => r.CreatedAt)
            .Take(20)
            .ToListAsync(ct);

        items.AddRange(reviews.Select(r => new ActivityItemDto(
            "review_written",
            r.UserId, r.User.UserName!, r.User.ProfilePhotoUrl,
            r.Book.Title, r.Book.CoverImageUrl,
            null, r.Rating, r.Comment, null,
            r.CreatedAt)));

        // ── Milestones (25 / 50 / 75%) ───────────────────────────────────────
        // We approximate milestones from UpdatedAt when progress crossed a threshold.
        // In a fuller implementation these would be events; here we emit one milestone
        // per user-book that is in the 25-99% range and was updated recently.
        var milestones = await uow.UserBooks.Query()
            .Include(ub => ub.User)
            .Include(ub => ub.Book)
            .Where(ub => allFriendIds.Contains(ub.UserId)
                      && !ub.IsCompleted
                      && ub.ReadingProgressPercent >= 25
                      && ub.UpdatedAt.HasValue
                      && ub.UpdatedAt >= since)
            .OrderByDescending(ub => ub.UpdatedAt)
            .Take(20)
            .ToListAsync(ct);

        items.AddRange(milestones.Select(ub =>
        {
            var pct = (int)(ub.ReadingProgressPercent / 25) * 25;
            pct = Math.Min(pct, 75);
            return new ActivityItemDto(
                "milestone",
                ub.UserId, ub.User.UserName!, ub.User.ProfilePhotoUrl,
                ub.Book.Title, ub.Book.CoverImageUrl,
                pct, null, null, null,
                ub.UpdatedAt!.Value);
        }));

        return items
            .OrderByDescending(i => i.Timestamp)
            .Take(40);
    }
}
