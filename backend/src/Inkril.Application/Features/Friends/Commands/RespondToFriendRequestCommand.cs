using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Friends.Commands;

public record RespondToFriendRequestCommand(Guid RequestId, Guid ResponderId, bool Accept) : IRequest<Result>;

public class RespondToFriendRequestCommandValidator : AbstractValidator<RespondToFriendRequestCommand>
{
    public RespondToFriendRequestCommandValidator()
    {
        RuleFor(x => x.RequestId).NotEmpty();
        RuleFor(x => x.ResponderId).NotEmpty();
    }
}

public class RespondToFriendRequestCommandHandler(IUnitOfWork uow)
    : IRequestHandler<RespondToFriendRequestCommand, Result>
{
    public async Task<Result> Handle(RespondToFriendRequestCommand cmd, CancellationToken ct)
    {
        var request = await uow.FriendRequests.FirstOrDefaultAsync(
            r => r.Id == cmd.RequestId &&
                 r.ReceiverId == cmd.ResponderId &&
                 r.Status == FriendRequestStatus.Pending, ct);

        if (request is null)
            return Result.Failure("Friend request not found or already responded to.");

        request.Status = cmd.Accept ? FriendRequestStatus.Accepted : FriendRequestStatus.Rejected;
        request.RespondedAt = DateTime.UtcNow;
        request.UpdatedAt = DateTime.UtcNow;
        uow.FriendRequests.Update(request);

        if (cmd.Accept)
        {
            await uow.Friendships.AddAsync(new Friendship
            {
                UserId = request.SenderId,
                FriendId = request.ReceiverId,
                FriendsSince = DateTime.UtcNow,
                CreatedBy = cmd.ResponderId.ToString()
            }, ct);

            await uow.Friendships.AddAsync(new Friendship
            {
                UserId = request.ReceiverId,
                FriendId = request.SenderId,
                FriendsSince = DateTime.UtcNow,
                CreatedBy = cmd.ResponderId.ToString()
            }, ct);

            // Notify the original sender that their request was accepted.
            await uow.Notifications.AddAsync(new Notification
            {
                UserId      = request.SenderId,
                Type        = NotificationType.FriendRequestAccepted,
                Title       = "Friend request accepted",
                Message     = "Your friend request has been accepted!",
                ReferenceId = request.ReceiverId,
                CreatedBy   = cmd.ResponderId.ToString()
            }, ct);
        }
        else
        {
            // Notify the sender that their request was declined.
            await uow.Notifications.AddAsync(new Notification
            {
                UserId      = request.SenderId,
                Type        = NotificationType.FriendRequestRejected,
                Title       = "Friend request declined",
                Message     = "Your friend request was not accepted.",
                ReferenceId = request.ReceiverId,
                CreatedBy   = cmd.ResponderId.ToString()
            }, ct);
        }

        await uow.SaveChangesAsync(ct);
        return Result.Success();
    }
}
