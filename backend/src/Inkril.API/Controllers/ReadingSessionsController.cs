using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.ReadingSessions.Commands;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/reading-sessions")]
[Authorize]
public class ReadingSessionsController(
    IMediator mediator,
    IUnitOfWork uow,
    ICurrentUserService currentUser) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Start([FromBody] StartReadingSessionCommand cmd, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(cmd with { UserId = userId }, ct);
        return result.Succeeded
            ? CreatedAtAction(nameof(Start), new { id = result.Value }, new { id = result.Value })
            : BadRequest(new { errors = result.Errors });
    }

    [HttpPut("{id:guid}/end")]
    public async Task<IActionResult> End(Guid id, [FromBody] EndSessionRequest req, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new EndReadingSessionCommand(id, userId, req.EndPage, req.TotalPdfPages), ct);
        return result.Succeeded ? NoContent() : BadRequest(new { errors = result.Errors });
    }

    [HttpGet("my")]
    public async Task<IActionResult> GetMySessions(CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var sessions = await uow.ReadingSessions.FindAsync(s => s.UserId == userId, ct);
        return Ok(sessions.OrderByDescending(s => s.StartedAt).Take(20));
    }
}

public record EndSessionRequest(int EndPage, int? TotalPdfPages = null);
