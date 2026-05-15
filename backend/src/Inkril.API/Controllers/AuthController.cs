using Inkril.Application.Features.Auth.Commands;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController(IMediator mediator) : ApiControllerBase
{
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return ToResult(result, Ok);
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return result.Succeeded
            ? Ok(result.Value)
            : Problem(detail: result.Errors[0], statusCode: 401, title: "Authentication failed.");
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshTokenCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return result.Succeeded
            ? Ok(result.Value)
            : Problem(detail: result.Errors[0], statusCode: 401, title: "Authentication failed.");
    }

    /// <summary>
    /// Sends a 6-digit OTP to the given email (if registered).
    /// Always returns 200 to prevent email enumeration.
    /// </summary>
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        // Always 200 — the message itself is deliberately vague.
        return ToResult(result, msg => Ok(new { message = msg }));
    }

    /// <summary>
    /// Validates the OTP and sets a new password.
    /// </summary>
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return ToResult(result, msg => Ok(new { message = msg }));
    }

    /// <summary>
    /// Revokes the refresh token on the server so it cannot be used to issue new access tokens.
    /// The client must also clear its local token storage (§5 — server-side logout required).
    /// </summary>
    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout([FromBody] LogoutCommand cmd, CancellationToken ct)
    {
        var result = await mediator.Send(cmd, ct);
        return ToResult(result, NoContent());
    }
}
