using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Auth.Commands;

/// <summary>
/// Resends the email-verification OTP for an account whose email is not yet confirmed.
/// Always returns the same blind message to prevent enumeration.
/// </summary>
public record ResendVerificationCommand(string Email) : IRequest<Result<string>>;

public class ResendVerificationCommandValidator : AbstractValidator<ResendVerificationCommand>
{
    public ResendVerificationCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
    }
}

public class ResendVerificationCommandHandler(
    UserManager<ApplicationUser> userManager,
    IEmailService emailService)
    : IRequestHandler<ResendVerificationCommand, Result<string>>
{
    private const string BlindMessage =
        "If that email is registered and unverified, a new code has been sent.";

    public async Task<Result<string>> Handle(ResendVerificationCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByEmailAsync(cmd.Email);

        if (user is not null && !user.IsDeleted && !user.EmailConfirmed)
        {
            var otp    = Random.Shared.Next(100_000, 999_999).ToString();
            var expiry = DateTime.UtcNow.AddMinutes(30);

            await userManager.SetAuthenticationTokenAsync(
                user, "Inkril", "EmailVerificationOtp", $"{otp}:{expiry.Ticks}");

            var html = $"""
                <div style="font-family:sans-serif;max-width:480px;margin:auto">
                  <h2 style="color:#6B21A8">Inkril — Verify Your Email</h2>
                  <p>Use the code below to verify your email address. It expires in <strong>30 minutes</strong>.</p>
                  <div style="margin:24px 0;padding:20px;background:#FAF5FF;border-radius:12px;text-align:center">
                    <span style="font-size:40px;font-weight:900;letter-spacing:12px;color:#6B21A8">{otp}</span>
                  </div>
                  <p style="color:#6B7280;font-size:13px">
                    If you didn't create an Inkril account, you can safely ignore this email.
                  </p>
                </div>
                """;

            await emailService.SendAsync(
                cmd.Email, "Inkril — Verify your email address", html, ct);
        }

        return Result<string>.Success(BlindMessage);
    }
}
