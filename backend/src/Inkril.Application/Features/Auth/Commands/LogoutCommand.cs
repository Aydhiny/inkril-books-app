using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Auth.Commands;

public record LogoutCommand(string RefreshToken) : IRequest<Result>;

public class LogoutCommandHandler(ITokenService tokenService)
    : IRequestHandler<LogoutCommand, Result>
{
    public async Task<Result> Handle(LogoutCommand cmd, CancellationToken ct)
    {
        var user = await tokenService.ValidateRefreshTokenAsync(cmd.RefreshToken);
        if (user is null)
            // Token already invalid — treat as success so clients don't get stuck
            return Result.Success();

        await tokenService.RevokeRefreshTokenAsync(user);
        return Result.Success();
    }
}
