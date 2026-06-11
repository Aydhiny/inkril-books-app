using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Auth.Commands;

public record RefreshTokenCommand(string RefreshToken) : IRequest<Result<AuthResponse>>;

public class RefreshTokenCommandHandler(ITokenService tokenService, UserManager<ApplicationUser> userManager)
    : IRequestHandler<RefreshTokenCommand, Result<AuthResponse>>
{
    public async Task<Result<AuthResponse>> Handle(
        RefreshTokenCommand cmd, CancellationToken cancellationToken)
    {
        var user = await tokenService.ValidateRefreshTokenAsync(cmd.RefreshToken);
        if (user is null)
            return Result<AuthResponse>.Failure("Invalid or expired refresh token.");

        if (!user.EmailConfirmed)
            return Result<AuthResponse>.Failure("Email address has not been verified.");

        if (user.IsBlocked)
            return Result<AuthResponse>.Failure("This account has been suspended.");

        if (user.IsDeleted)
            return Result<AuthResponse>.Failure("Invalid or expired refresh token.");

        var roles = await userManager.GetRolesAsync(user);
        var role  = roles.Contains("desktop") ? "desktop" : "mobile";

        var (access, refresh) = await tokenService.GenerateTokensAsync(user);
        return Result<AuthResponse>.Success(
            new AuthResponse(access, refresh, user.Id, user.UserName!, user.Email!, role));
    }
}
