using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Users.Commands;
using Inkril.Application.Features.Users.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController(IMediator mediator, ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> GetAll([FromQuery] GetUsersQuery query, CancellationToken ct)
        => Ok(await mediator.Send(query, ct));

    [HttpPut("{id:guid}/status")]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateUserStatusCommand cmd, CancellationToken ct)
    {
        if (id != cmd.UserId) return BadRequest("Route ID and body ID do not match.");
        var result = await mediator.Send(cmd, ct);
        return result.Succeeded ? NoContent() : BadRequest(new { errors = result.Errors });
    }

    [HttpGet("{id:guid}/profile")]
    public async Task<IActionResult> GetProfile(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new GetUserProfileQuery(id), ct);
        return result.Succeeded ? Ok(result.Value) : NotFound(new { message = result.Errors[0] });
    }

    [HttpGet("me/profile")]
    public async Task<IActionResult> GetMyProfile(CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new GetUserProfileQuery(userId), ct);
        return result.Succeeded ? Ok(result.Value) : NotFound(new { message = result.Errors[0] });
    }

    [HttpPut("me/profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileCommand cmd, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(cmd with { UserId = userId }, ct);
        return result.Succeeded ? NoContent() : BadRequest(new { errors = result.Errors });
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string q, CancellationToken ct)
        => Ok(await mediator.Send(new SearchUsersQuery(q), ct));
}
