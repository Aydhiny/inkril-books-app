using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;

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
    ITokenService tokenService,
    IEmailService emailService,
    ILogger<RegisterCommandHandler> logger
) : IRequestHandler<RegisterCommand, Result<AuthResponse>>
{
    public async Task<Result<AuthResponse>> Handle(RegisterCommand cmd, CancellationToken ct)
    {
        if (await userManager.FindByEmailAsync(cmd.Email) is not null)
            return Result<AuthResponse>.Failure("An account with this email already exists.");

        var user = new ApplicationUser
        {
            FirstName     = cmd.FirstName,
            LastName      = cmd.LastName,
            Email         = cmd.Email,
            UserName      = cmd.UserName,
            // Email must be verified before the user can access the app.
            // The client receives an access token and is redirected to the
            // verification screen; all guarded endpoints check EmailConfirmed
            // via the [EmailVerified] attribute applied in Program.cs.
            EmailConfirmed = false
        };

        var identityResult = await userManager.CreateAsync(user, cmd.Password);
        if (!identityResult.Succeeded)
            return Result<AuthResponse>.Failure(identityResult.Errors.Select(e => e.Description).ToArray());

        await userManager.AddToRoleAsync(user, "mobile");

        // Create default settings for new user
        await uow.UserSettings.AddAsync(new UserSettings { UserId = user.Id }, ct);
        await uow.SaveChangesAsync(ct);

        // Send email verification OTP — fire-and-forget with error swallowing
        // so a misconfigured SMTP does not fail the registration itself.
        try
        {
            var otp    = Random.Shared.Next(100_000, 999_999).ToString();
            var expiry = DateTime.UtcNow.AddMinutes(30);

            await userManager.SetAuthenticationTokenAsync(
                user, "Inkril", "EmailVerificationOtp", $"{otp}:{expiry.Ticks}");

            var html = $"""
                <div style="font-family:sans-serif;max-width:480px;margin:auto">
                  <h2 style="color:#6B21A8">Welcome to Inkril!</h2>
                  <p>Enter this code in the app to verify your email address. It expires in <strong>30 minutes</strong>.</p>
                  <div style="margin:24px 0;padding:20px;background:#FAF5FF;border-radius:12px;text-align:center">
                    <span style="font-size:40px;font-weight:900;letter-spacing:12px;color:#6B21A8">{otp}</span>
                  </div>
                  <p style="color:#6B7280;font-size:13px">
                    If you didn't create an Inkril account, you can safely ignore this email.
                  </p>
                </div>
                """;

            await emailService.SendAsync(cmd.Email, "Inkril — Verify your email address", html, ct);
        }
        catch (Exception ex)
        {
            // Log but don't fail — the user can resend via POST /api/auth/resend-verification
            logger.LogWarning(ex, "Failed to send verification email to {Email}", cmd.Email);
        }

        var (access, refresh) = await tokenService.GenerateTokensAsync(user);
        return Result<AuthResponse>.Success(new AuthResponse(access, refresh, user.Id, user.UserName!, user.Email!));
    }
}

