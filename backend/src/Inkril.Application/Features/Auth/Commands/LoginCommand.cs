using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Auth.Commands;

public record LoginCommand(string UserNameOrEmail, string Password) : IRequest<Result<AuthResponse>>;

public class LoginCommandValidator : AbstractValidator<LoginCommand>
{
    public LoginCommandValidator()
    {
        RuleFor(x => x.UserNameOrEmail).NotEmpty();
        RuleFor(x => x.Password).NotEmpty();
    }
}

public class LoginCommandHandler(
    UserManager<ApplicationUser> userManager,
    ITokenService tokenService
) : IRequestHandler<LoginCommand, Result<AuthResponse>>
{
    public async Task<Result<AuthResponse>> Handle(LoginCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByEmailAsync(cmd.UserNameOrEmail)
                   ?? await userManager.FindByNameAsync(cmd.UserNameOrEmail);

        // All failure paths return the same message. Differentiated messages
        // ("account inactive" vs "wrong password") are a user-enumeration oracle —
        // an attacker learns whether an account exists without valid credentials.
        const string InvalidMsg = "Invalid credentials.";

        if (user is null || user.IsDeleted || user.IsBlocked)
            return Result<AuthResponse>.Failure(InvalidMsg);

        if (!await userManager.CheckPasswordAsync(user, cmd.Password))
            return Result<AuthResponse>.Failure(InvalidMsg);

        // Require email verification before granting access.
        // This check intentionally comes AFTER the password check so we don't
        // leak whether an account exists to unauthenticated callers.
        if (!user.EmailConfirmed)
            return Result<AuthResponse>.Failure(
                "Please verify your email before logging in. " +
                "Check your inbox for a 6-digit code, or use POST /api/auth/resend-verification.");

        var (access, refresh) = await tokenService.GenerateTokensAsync(user);
        return Result<AuthResponse>.Success(new AuthResponse(access, refresh, user.Id, user.UserName!, user.Email!));
    }
}
