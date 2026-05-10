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

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new DeleteUserCommand(id), ct);
        return result.Succeeded ? NoContent() : NotFound(new { message = result.Errors[0] });
    }

    [HttpPut("{id:guid}/roles")]
    [Authorize(Roles = "desktop")]
    public async Task<IActionResult> UpdateRoles(Guid id, [FromBody] UpdateUserRolesCommand cmd, CancellationToken ct)
    {
        if (id != cmd.UserId) return BadRequest("Route ID and body ID do not match.");
        var result = await mediator.Send(cmd, ct);
        return result.Succeeded ? NoContent() : BadRequest(new { errors = result.Errors });
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string q, CancellationToken ct)
        => Ok(await mediator.Send(new SearchUsersQuery(q), ct));

    /// <summary>
    /// Returns daily reading minutes for every active day in <paramref name="year"/>.
    /// Zero-minute days are omitted — the client fills them with an empty colour.
    /// </summary>
    [HttpGet("me/reading-stats/heatmap")]
    public async Task<IActionResult> GetReadingHeatmap(
        [FromQuery] int? year, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var y = year ?? DateTime.UtcNow.Year;
        var result = await mediator.Send(new GetReadingHeatmapQuery(userId, y), ct);
        return result.Succeeded ? Ok(result.Value) : BadRequest(new { errors = result.Errors });
    }
}
