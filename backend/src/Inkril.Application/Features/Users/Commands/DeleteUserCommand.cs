using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Users.Commands;

public record DeleteUserCommand(Guid UserId) : IRequest<Result>;

public class DeleteUserCommandHandler(
    UserManager<ApplicationUser> userManager,
    ITokenService tokenService)
    : IRequestHandler<DeleteUserCommand, Result>
{
    public async Task<Result> Handle(DeleteUserCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByIdAsync(cmd.UserId.ToString());
        if (user is null || user.IsDeleted)
            return Result.Failure("User not found.");

        user.IsDeleted = true;
        user.UpdatedAt = DateTime.UtcNow;
        await userManager.UpdateAsync(user);

        // Revoke all refresh tokens immediately so the deleted user cannot obtain
        // new access tokens even if they still hold a valid refresh token.
        await tokenService.RevokeRefreshTokenAsync(user);

        return Result.Success();
    }
}
