using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Application.Features.Notifications.Commands;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController(
    IMediator mediator,
    IUnitOfWork uow,
    ICurrentUserService currentUser) : ApiControllerBase
{
    private const int MaxPageSize = 50;

    [HttpGet]
    public async Task<IActionResult> GetMyNotifications(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        pageSize = Math.Min(pageSize, MaxPageSize);

        var query = uow.Notifications.Query()
            .Where(n => n.UserId == userId && !n.IsDeleted);

        var total = await query.CountAsync(ct);
        var paged = await query
            .OrderByDescending(n => n.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return Ok(new PagedList<object>(
            paged.Select(n => (object)n),
            total,
            pageNumber,
            pageSize));
    }

    [HttpPut("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new MarkNotificationReadCommand(id, userId), ct);
        return ToResult(result, NoContent());
    }

    [HttpPut("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new MarkAllNotificationsReadCommand(userId), ct);
        return ToResult(result, NoContent());
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Dismiss(Guid id, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var notification = await uow.Notifications.GetByIdAsync(id, ct);
        if (notification is null || notification.UserId != userId)
            return NotFound();

        uow.Notifications.SoftDelete(notification);
        await uow.SaveChangesAsync(ct);
        return NoContent();
    }
}
