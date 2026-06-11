using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using UserSettingsEntity = Inkril.Domain.Entities.UserSettings;

namespace Inkril.Application.Features.Auth.Commands;

public record RegisterCommand(
    string FirstName,
    string LastName,
    string Email,
    string UserName,
    string Password
) : IRequest<Result<string>>;

public record AuthResponse(string AccessToken, string RefreshToken, Guid UserId, string UserName, string Email, string Role);

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
    IEmailService emailService,
    ILogger<RegisterCommandHandler> logger
) : IRequestHandler<RegisterCommand, Result<string>>
{
    public async Task<Result<string>> Handle(RegisterCommand cmd, CancellationToken ct)
    {
        if (await userManager.FindByEmailAsync(cmd.Email) is not null)
            return Result<string>.Failure("An account with this email already exists.");

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
            return Result<string>.Failure(identityResult.Errors.Select(e => e.Description).ToArray());

        await userManager.AddToRoleAsync(user, "mobile");

        // Create default settings for new user
        await uow.UserSettings.AddAsync(new UserSettingsEntity { UserId = user.Id }, ct);
        await uow.SaveChangesAsync(ct);

        // Send email verification OTP — fire-and-forget with error swallowing
        // so a misconfigured SMTP does not fail the registration itself.
        try
        {
            var otpBytes = new byte[4];
            System.Security.Cryptography.RandomNumberGenerator.Fill(otpBytes);
            var otp    = (Math.Abs(BitConverter.ToInt32(otpBytes, 0)) % 900_000 + 100_000).ToString();
            var expiry = DateTime.UtcNow.AddMinutes(30);

            // Format: "OTP:EXPIRY_TICKS:ATTEMPTS"
            await userManager.SetAuthenticationTokenAsync(
                user, "Inkril", "EmailVerificationOtp", $"{otp}:{expiry.Ticks}:0");

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

        // Tokens are NOT issued here. The client must verify the email via POST /api/auth/verify-email,
        // which returns fresh tokens only after EmailConfirmed = true.
        return Result<string>.Success(
            "Registration successful. Check your email for a 6-digit verification code.");
    }
}

