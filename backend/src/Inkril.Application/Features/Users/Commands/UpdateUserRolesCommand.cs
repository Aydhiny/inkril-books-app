using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Users.Commands;

public record UpdateUserRolesCommand(Guid UserId, IEnumerable<string> Roles) : IRequest<Result>;

public class UpdateUserRolesCommandHandler(UserManager<ApplicationUser> userManager)
    : IRequestHandler<UpdateUserRolesCommand, Result>
{
    public async Task<Result> Handle(UpdateUserRolesCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByIdAsync(cmd.UserId.ToString());
        if (user is null || user.IsDeleted)
            return Result.Failure("User not found.");

        var currentRoles = await userManager.GetRolesAsync(user);
        await userManager.RemoveFromRolesAsync(user, currentRoles);
        var result = await userManager.AddToRolesAsync(user, cmd.Roles);

        return result.Succeeded
            ? Result.Success()
            : Result.Failure(result.Errors.Select(e => e.Description).ToArray());
    }
}
