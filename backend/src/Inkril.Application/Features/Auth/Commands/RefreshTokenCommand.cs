using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Auth.Commands;

public record RefreshTokenCommand(string RefreshToken) : IRequest<Result<AuthResponse>>;

public class RefreshTokenCommandHandler(ITokenService tokenService)
    : IRequestHandler<RefreshTokenCommand, Result<AuthResponse>>
{
    public async Task<Result<AuthResponse>> Handle(
        RefreshTokenCommand cmd, CancellationToken cancellationToken)
    {
        var user = await tokenService.ValidateRefreshTokenAsync(cmd.RefreshToken);
        if (user is null)
            return Result<AuthResponse>.Failure("Invalid or expired refresh token.");

        var (access, refresh) = await tokenService.GenerateTokensAsync(user);
        return Result<AuthResponse>.Success(
            new AuthResponse(access, refresh, user.Id, user.UserName!, user.Email!));
    }
}
