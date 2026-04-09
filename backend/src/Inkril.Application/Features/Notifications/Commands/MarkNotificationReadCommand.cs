using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Notifications.Commands;

public record MarkNotificationReadCommand(Guid NotificationId, Guid UserId) : IRequest<Result>;

public class MarkNotificationReadCommandHandler(IUnitOfWork uow)
    : IRequestHandler<MarkNotificationReadCommand, Result>
{
    public async Task<Result> Handle(MarkNotificationReadCommand cmd, CancellationToken ct)
    {
        var notification = await uow.Notifications.GetByIdAsync(cmd.NotificationId, ct);
        if (notification is null || notification.UserId != cmd.UserId)
            return Result.Failure("Notification not found.");

        notification.IsRead = true;
        notification.ReadAt = DateTime.UtcNow;
        uow.Notifications.Update(notification);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
