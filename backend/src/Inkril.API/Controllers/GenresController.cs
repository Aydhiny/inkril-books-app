using Inkril.Application.Features.Genres.Commands;
using Inkril.Application.Features.Genres.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/genres")]
[Authorize]
public class GenresController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct)
        => Ok(await mediator.Send(new GetGenresQuery(), ct));

    [HttpPost]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> Create([FromBody] CreateGenreCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return result.Succeeded
            ? Ok(new { id = result.Value })
            : BadRequest(new { errors = result.Errors });
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateGenreCommand cmd, CancellationToken ct)
    {
        // Bind route id into the command record
        var result = await mediator.Send(cmd with { Id = id }, ct);
        return result.Succeeded
            ? NoContent()
            : BadRequest(new { errors = result.Errors });
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new DeleteGenreCommand(id), ct);
        return result.Succeeded
            ? NoContent()
            : BadRequest(new { errors = result.Errors });
    }
}
