using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Users.Commands;

public record UpdateUserStatusCommand(Guid UserId, bool IsBlocked, string? Reason) : IRequest<Result>;

public class UpdateUserStatusCommandHandler(
    UserManager<ApplicationUser> userManager,
    ITokenService tokenService)
    : IRequestHandler<UpdateUserStatusCommand, Result>
{
    public async Task<Result> Handle(UpdateUserStatusCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByIdAsync(cmd.UserId.ToString());
        if (user is null || user.IsDeleted)
            return Result.Failure("User not found.");

        user.IsBlocked = cmd.IsBlocked;
        user.UpdatedAt = DateTime.UtcNow;
        await userManager.UpdateAsync(user);

        // Revoke all refresh tokens so the blocked user cannot obtain new access tokens
        // without re-authenticating (which will now fail at the block check).
        if (cmd.IsBlocked)
            await tokenService.RevokeRefreshTokenAsync(user);

        return Result.Success();
    }
}
