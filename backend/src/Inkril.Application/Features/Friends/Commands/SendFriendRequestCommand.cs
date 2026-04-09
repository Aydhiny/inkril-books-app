using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;

namespace Inkril.Application.Features.Friends.Commands;

public record SendFriendRequestCommand(Guid SenderId, Guid ReceiverId) : IRequest<Result>;

public class SendFriendRequestCommandHandler(IUnitOfWork uow, IMessagePublisher publisher)
    : IRequestHandler<SendFriendRequestCommand, Result>
{
    public async Task<Result> Handle(SendFriendRequestCommand cmd, CancellationToken ct)
    {
        if (cmd.SenderId == cmd.ReceiverId)
            return Result.Failure("You cannot send a friend request to yourself.");

        var alreadyFriends = await uow.Friendships.AnyAsync(
            f => (f.UserId == cmd.SenderId && f.FriendId == cmd.ReceiverId) ||
                 (f.UserId == cmd.ReceiverId && f.FriendId == cmd.SenderId), ct);
        if (alreadyFriends)
            return Result.Failure("You are already friends with this user.");

        var pendingRequest = await uow.FriendRequests.AnyAsync(
            r => r.SenderId == cmd.SenderId && r.ReceiverId == cmd.ReceiverId
                 && r.Status == FriendRequestStatus.Pending, ct);
        if (pendingRequest)
            return Result.Failure("A friend request to this user is already pending.");

        var request = new FriendRequest
        {
            SenderId = cmd.SenderId,
            ReceiverId = cmd.ReceiverId,
            CreatedBy = cmd.SenderId.ToString()
        };

        await uow.FriendRequests.AddAsync(request, ct);
        await uow.SaveChangesAsync(ct);

        // Publish to RabbitMQ — NotificationWorker creates the in-app notification
        await publisher.PublishAsync(
            new { FriendRequestId = request.Id, SenderId = cmd.SenderId, ReceiverId = cmd.ReceiverId },
            routingKey: "friend.request.sent", ct);

        return Result.Success();
    }
}
