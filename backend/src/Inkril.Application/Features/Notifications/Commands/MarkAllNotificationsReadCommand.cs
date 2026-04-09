using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Notifications.Commands;

public record MarkAllNotificationsReadCommand(Guid UserId) : IRequest<Result<Unit>>;

public class MarkAllNotificationsReadCommandHandler(IUnitOfWork uow)
    : IRequestHandler<MarkAllNotificationsReadCommand, Result<Unit>>
{
    public async Task<Result<Unit>> Handle(MarkAllNotificationsReadCommand request, CancellationToken ct)
    {
        var unread = await uow.Notifications.FindAsync(
            n => n.UserId == request.UserId && !n.IsRead, ct);

        foreach (var n in unread)
        {
            n.IsRead = true;
            n.UpdatedAt = DateTime.UtcNow;
            uow.Notifications.Update(n);
        }

        await uow.SaveChangesAsync(ct);
        return Result<Unit>.Success(Unit.Value);
    }
}
