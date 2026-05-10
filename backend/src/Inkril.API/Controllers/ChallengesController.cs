using Inkril.Application.Features.Challenges;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ChallengesController(IMediator mediator) : ControllerBase
{
    /// <summary>Returns today's challenges with live progress for the current user.</summary>
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
        => Ok(await mediator.Send(new GetChallengesQuery(), ct));
}
