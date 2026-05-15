using Inkril.Application.Features.UserSettings.Commands;
using Inkril.Application.Features.UserSettings.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/user-settings")]
[Authorize]
public class UserSettingsController(IMediator mediator) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var result = await mediator.Send(new GetUserSettingsQuery(), ct);
        return ToResult(result, Ok);
    }

    [HttpPut]
    public async Task<IActionResult> Update(
        [FromBody] UpdateUserSettingsCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return ToResult(result, NoContent());
    }
}
