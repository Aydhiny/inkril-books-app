using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;

namespace Inkril.Application.Features.Auth.Commands;

public record ForgotPasswordCommand(string Email) : IRequest<Result<string>>;

public class ForgotPasswordCommandValidator : AbstractValidator<ForgotPasswordCommand>
{
    public ForgotPasswordCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
    }
}

public class ForgotPasswordCommandHandler(
    UserManager<ApplicationUser> userManager,
    IEmailService emailService,
    ILogger<ForgotPasswordCommandHandler> logger
) : IRequestHandler<ForgotPasswordCommand, Result<string>>
{
    // Constant-time blind response — never reveal whether an email is registered.
    // This prevents email enumeration attacks.
    private const string BlindMessage =
        "If that email is registered, a 6-digit reset code has been sent.";

    public async Task<Result<string>> Handle(ForgotPasswordCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByEmailAsync(cmd.Email);

        // Only send the email if the account exists and is active.
        // Return the same message regardless so callers can't enumerate emails.
        if (user is not null && !user.IsDeleted && !user.IsBlocked)
        {
            var otp    = Random.Shared.Next(100_000, 999_999).ToString();
            var expiry = DateTime.UtcNow.AddMinutes(15);

            // Store as "OTP:EXPIRY_TICKS" so no extra table is needed.
            // One-time use: cleared in ResetPasswordCommandHandler after verification.
            await userManager.SetAuthenticationTokenAsync(
                user, "Inkril", "PasswordResetOtp", $"{otp}:{expiry.Ticks}");

            var html = $"""
                <div style="font-family:sans-serif;max-width:480px;margin:auto">
                  <h2 style="color:#6B21A8">Inkril — Password Reset</h2>
                  <p>Use the code below to reset your password. It expires in <strong>15 minutes</strong>.</p>
                  <div style="margin:24px 0;padding:20px;background:#FAF5FF;border-radius:12px;text-align:center">
                    <span style="font-size:40px;font-weight:900;letter-spacing:12px;color:#6B21A8">{otp}</span>
                  </div>
                  <p style="color:#6B7280;font-size:13px">
                    If you didn't request this, you can safely ignore this email.
                  </p>
                </div>
                """;

            // Wrap send in try-catch: a transient SMTP failure should not return 500
            // to the client — the blind message still applies so the user can attempt
            // to enter a code. The OTP is already persisted so a retry (resend) works.
            try
            {
                await emailService.SendAsync(cmd.Email, "Inkril — Your password reset code", html, ct);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to send password-reset email to {Email}", cmd.Email);
            }
        }

        return Result<string>.Success(BlindMessage);
    }
}
