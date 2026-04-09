using Inkril.Application.Features.Genres.Commands;
using Inkril.Application.Features.Genres.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/genres")]
public class GenresController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    [AllowAnonymous]
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
}
