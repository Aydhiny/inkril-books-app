using FluentValidation;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Auth.Commands;

public record ResetPasswordCommand(
    string Email,
    string Otp,
    string NewPassword
) : IRequest<Result<string>>;

public class ResetPasswordCommandValidator : AbstractValidator<ResetPasswordCommand>
{
    public ResetPasswordCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Otp)
            .NotEmpty()
            .Length(6)
            .Matches(@"^\d{6}$").WithMessage("OTP must be exactly 6 digits.");
        RuleFor(x => x.NewPassword)
            .NotEmpty()
            .MinimumLength(8).WithMessage("Password must be at least 8 characters.");
    }
}

public class ResetPasswordCommandHandler(
    UserManager<ApplicationUser> userManager
) : IRequestHandler<ResetPasswordCommand, Result<string>>
{
    // Generic error used for all failure paths — prevents an attacker from
    // learning whether a given email is registered or the OTP is close.
    private const string GenericError = "Invalid or expired reset code.";

    public async Task<Result<string>> Handle(ResetPasswordCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByEmailAsync(cmd.Email);
        if (user is null || user.IsDeleted)
            return Result<string>.Failure(GenericError);

        var stored = await userManager.GetAuthenticationTokenAsync(
            user, "Inkril", "PasswordResetOtp");

        if (stored is null)
            return Result<string>.Failure(GenericError);

        // Stored format: "OTP:EXPIRY_TICKS:ATTEMPTS"
        var parts = stored.Split(':');
        if (parts.Length != 3
            || !long.TryParse(parts[1], out var ticks)
            || !int.TryParse(parts[2], out var attempts))
            return Result<string>.Failure(GenericError);

        // Lock after 5 failed attempts — user must request a new reset code.
        if (attempts >= 5)
            return Result<string>.Failure(
                "Too many failed attempts. Please request a new reset code.");

        var expiry = new DateTime(ticks, DateTimeKind.Utc);
        if (DateTime.UtcNow > expiry)
            return Result<string>.Failure("Reset code has expired. Please request a new one.");

        if (!CryptographicEquals(parts[0], cmd.Otp))
        {
            await userManager.SetAuthenticationTokenAsync(
                user, "Inkril", "PasswordResetOtp",
                $"{parts[0]}:{parts[1]}:{attempts + 1}");
            await userManager.UpdateAsync(user);
            return Result<string>.Failure(GenericError);
        }

        // Invalidate OTP immediately — one-time use
        await userManager.RemoveAuthenticationTokenAsync(user, "Inkril", "PasswordResetOtp");

        // Generate a fresh Identity reset token and consume it in one step.
        // This avoids exposing the raw Identity token over the network.
        var resetToken = await userManager.GeneratePasswordResetTokenAsync(user);
        var result     = await userManager.ResetPasswordAsync(user, resetToken, cmd.NewPassword);

        if (!result.Succeeded)
            return Result<string>.Failure(result.Errors.Select(e => e.Description).ToArray());

        return Result<string>.Success("Password reset successfully. You can now log in.");
    }

    // XOR all characters so the loop always runs to completion — prevents
    // early-exit timing leaks that would let an attacker binary-search the OTP.
    private static bool CryptographicEquals(string a, string b)
    {
        if (a.Length != b.Length) return false;
        var diff = 0;
        for (var i = 0; i < a.Length; i++)
            diff |= a[i] ^ b[i];
        return diff == 0;
    }
}
