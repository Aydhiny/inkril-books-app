using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.UserBooks.Queries;

/// <summary>
/// Returns progress data for friends who have the same book in their library.
/// Used by the buddy-reading overlay in the mobile reader.
/// </summary>
public record FriendProgressDto(
    string UserName,
    int CurrentPage,
    double ProgressPercent);

public record GetFriendsProgressQuery(Guid UserId, Guid BookId)
    : IRequest<Result<IEnumerable<FriendProgressDto>>>;

public class GetFriendsProgressQueryHandler(
    IUnitOfWork uow,
    UserManager<ApplicationUser> userManager)
    : IRequestHandler<GetFriendsProgressQuery, Result<IEnumerable<FriendProgressDto>>>
{
    public async Task<Result<IEnumerable<FriendProgressDto>>> Handle(
        GetFriendsProgressQuery q, CancellationToken ct)
    {
        // 1. Resolve friend IDs from the bidirectional friendship table
        var friendships = await uow.Friendships.FindAsync(
            f => f.UserId == q.UserId, ct);
        var friendIds = friendships.Select(f => f.FriendId).ToHashSet();

        if (friendIds.Count == 0)
            return Result<IEnumerable<FriendProgressDto>>.Success([]);

        // 2. Find UserBook rows for those friends on this specific book
        var friendBooks = await uow.UserBooks.FindAsync(
            ub => friendIds.Contains(ub.UserId) && ub.BookId == q.BookId, ct);

        var result = new List<FriendProgressDto>();

        foreach (var ub in friendBooks)
        {
            var user = await userManager.FindByIdAsync(ub.UserId.ToString());
            if (user is null || user.IsDeleted) continue;

            result.Add(new FriendProgressDto(
                user.UserName!,
                ub.LastReadPageNumber,
                Math.Round(ub.ReadingProgressPercent, 1)));
        }

        return Result<IEnumerable<FriendProgressDto>>.Success(result);
    }
}
