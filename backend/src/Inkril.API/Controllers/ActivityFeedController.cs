using Inkril.Application.Features.ActivityFeed;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/activity-feed")]
[Authorize]
public class ActivityFeedController(IMediator mediator) : ApiControllerBase
{
    /// <summary>Returns the last 14 days of reading activity from the user's friends.</summary>
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
        => Ok(await mediator.Send(new GetActivityFeedQuery(), ct));
}
