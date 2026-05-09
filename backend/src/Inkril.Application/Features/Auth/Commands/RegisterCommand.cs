using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Auth.Commands;

public record RegisterCommand(
    string FirstName,
    string LastName,
    string Email,
    string UserName,
    string Password
) : IRequest<Result<AuthResponse>>;

public record AuthResponse(string AccessToken, string RefreshToken, Guid UserId, string UserName, string Email);

public class RegisterCommandValidator : AbstractValidator<RegisterCommand>
{
    public RegisterCommandValidator()
    {
        RuleFor(x => x.FirstName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.LastName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Email).NotEmpty().EmailAddress().WithMessage("Please enter a valid email address.");
        RuleFor(x => x.UserName).NotEmpty().MinimumLength(3).MaximumLength(50);
        RuleFor(x => x.Password).NotEmpty().MinimumLength(8)
            .WithMessage("Password must be at least 8 characters.");
    }
}

public class RegisterCommandHandler(
    UserManager<ApplicationUser> userManager,
    IUnitOfWork uow,
    ITokenService tokenService
) : IRequestHandler<RegisterCommand, Result<AuthResponse>>
{
    public async Task<Result<AuthResponse>> Handle(RegisterCommand cmd, CancellationToken ct)
    {
        if (await userManager.FindByEmailAsync(cmd.Email) is not null)
            return Result<AuthResponse>.Failure("An account with this email already exists.");

        var user = new ApplicationUser
        {
            FirstName = cmd.FirstName,
            LastName = cmd.LastName,
            Email = cmd.Email,
            UserName = cmd.UserName,
            EmailConfirmed = true
        };

        var identityResult = await userManager.CreateAsync(user, cmd.Password);
        if (!identityResult.Succeeded)
            return Result<AuthResponse>.Failure(identityResult.Errors.Select(e => e.Description).ToArray());

        await userManager.AddToRoleAsync(user, "mobile");

        // Create default settings for new user
        await uow.UserSettings.AddAsync(new Inkril.Domain.Entities.UserSettings { UserId = user.Id }, ct);
        await uow.SaveChangesAsync(ct);

        var (access, refresh) = await tokenService.GenerateTokensAsync(user);
        return Result<AuthResponse>.Success(new AuthResponse(access, refresh, user.Id, user.UserName!, user.Email!));
    }
}

// Defined here to avoid a circular project reference
public interface ITokenService
{
    Task<(string AccessToken, string RefreshToken)> GenerateTokensAsync(ApplicationUser user);
    Task<ApplicationUser?> ValidateRefreshTokenAsync(string refreshToken);
}
