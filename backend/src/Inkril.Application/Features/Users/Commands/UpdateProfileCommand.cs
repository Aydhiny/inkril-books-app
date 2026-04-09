using FluentValidation;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Users.Commands;

public record UpdateProfileCommand(
    Guid UserId,
    string FirstName,
    string LastName,
    string? Bio,
    string? ProfilePhotoUrl
) : IRequest<Result>;

public class UpdateProfileCommandValidator : AbstractValidator<UpdateProfileCommand>
{
    public UpdateProfileCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.FirstName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.LastName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Bio).MaximumLength(500).When(x => x.Bio != null);
    }
}

public class UpdateProfileCommandHandler(UserManager<ApplicationUser> userManager)
    : IRequestHandler<UpdateProfileCommand, Result>
{
    public async Task<Result> Handle(UpdateProfileCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByIdAsync(cmd.UserId.ToString());
        if (user is null || user.IsDeleted)
            return Result.Failure("User not found.");

        user.FirstName = cmd.FirstName;
        user.LastName = cmd.LastName;
        user.Bio = cmd.Bio;
        user.ProfilePhotoUrl = cmd.ProfilePhotoUrl;
        user.UpdatedAt = DateTime.UtcNow;

        await userManager.UpdateAsync(user);
        return Result.Success();
    }
}
