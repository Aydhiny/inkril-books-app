using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Users.Commands;

public record DeleteUserCommand(Guid UserId) : IRequest<Result>;

public class DeleteUserCommandHandler(UserManager<ApplicationUser> userManager)
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
        return Result.Success();
    }
}
