using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Application.Features.ReadingSessions.Commands;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/reading-sessions")]
[Authorize]
public class ReadingSessionsController(
    IMediator mediator,
    IUnitOfWork uow,
    ICurrentUserService currentUser) : ApiControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Start([FromBody] StartReadingSessionCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return ToResult(result, id => CreatedAtAction(nameof(Start), new { id }, new { id }));
    }

    [HttpPut("{id:guid}/end")]
    public async Task<IActionResult> End(Guid id, [FromBody] EndSessionRequest req, CancellationToken ct)
    {
        var result = await mediator.Send(new EndReadingSessionCommand(id, req.EndPage), ct);
        return ToResult(result, NoContent());
    }

    [HttpGet("my")]
    public async Task<IActionResult> GetMySessions(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        pageSize = Math.Min(pageSize, 50);

        var query = uow.ReadingSessions.Query()
            .Where(s => s.UserId == userId && !s.IsDeleted);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(s => s.StartedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return Ok(new PagedList<object>(
            items.Select(s => (object)s),
            total,
            pageNumber,
            pageSize));
    }
}

public record EndSessionRequest(int EndPage);
