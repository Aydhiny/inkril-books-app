using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Auth.Commands;

/// <summary>
/// Validates the 6-digit OTP that was emailed during registration and marks
/// the account's email as confirmed. Returns fresh auth tokens so the client
/// is immediately logged in after verification — no extra login step required.
/// </summary>
public record VerifyEmailCommand(string Email, string Otp) : IRequest<Result<AuthResponse>>;

public class VerifyEmailCommandValidator : AbstractValidator<VerifyEmailCommand>
{
    public VerifyEmailCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Otp)
            .NotEmpty()
            .Length(6)
            .Matches(@"^\d{6}$").WithMessage("OTP must be exactly 6 digits.");
    }
}

public class VerifyEmailCommandHandler(
    UserManager<ApplicationUser> userManager,
    ITokenService tokenService)
    : IRequestHandler<VerifyEmailCommand, Result<AuthResponse>>
{
    private const string GenericError = "Invalid or expired verification code.";

    public async Task<Result<AuthResponse>> Handle(VerifyEmailCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByEmailAsync(cmd.Email);
        if (user is null || user.IsDeleted)
            return Result<AuthResponse>.Failure(GenericError);

        // If already verified, issue fresh tokens so the client can proceed
        if (user.EmailConfirmed)
        {
            var (a, r) = await tokenService.GenerateTokensAsync(user);
            var existingRoles = await userManager.GetRolesAsync(user);
            var existingRole  = existingRoles.Contains("desktop") ? "desktop" : "mobile";
            return Result<AuthResponse>.Success(new AuthResponse(a, r, user.Id, user.UserName!, user.Email!, existingRole));
        }

        var stored = await userManager.GetAuthenticationTokenAsync(
            user, "Inkril", "EmailVerificationOtp");

        if (stored is null)
            return Result<AuthResponse>.Failure(GenericError);

        // Stored format: "OTP:EXPIRY_TICKS:ATTEMPTS"
        var parts = stored.Split(':');
        if (parts.Length != 3
            || !long.TryParse(parts[1], out var ticks)
            || !int.TryParse(parts[2], out var attempts))
            return Result<AuthResponse>.Failure(GenericError);

        // Lock after 5 failed attempts — user must request a new code via resend.
        if (attempts >= 5)
            return Result<AuthResponse>.Failure(
                "Too many failed attempts. Please request a new verification code.");

        var expiry = new DateTime(ticks, DateTimeKind.Utc);
        if (DateTime.UtcNow > expiry)
            return Result<AuthResponse>.Failure("Verification code has expired. Please request a new one.");

        if (!CryptographicEquals(parts[0], cmd.Otp))
        {
            // Persist incremented attempt count before returning the generic error.
            await userManager.SetAuthenticationTokenAsync(
                user, "Inkril", "EmailVerificationOtp",
                $"{parts[0]}:{parts[1]}:{attempts + 1}");
            await userManager.UpdateAsync(user);
            return Result<AuthResponse>.Failure(GenericError);
        }

        // Invalidate OTP and mark email as confirmed
        await userManager.RemoveAuthenticationTokenAsync(user, "Inkril", "EmailVerificationOtp");
        user.EmailConfirmed = true;
        await userManager.UpdateAsync(user);

        // Return fresh tokens — client is now logged in immediately
        var (access, refresh) = await tokenService.GenerateTokensAsync(user);
        var roles = await userManager.GetRolesAsync(user);
        var role  = roles.Contains("desktop") ? "desktop" : "mobile";
        return Result<AuthResponse>.Success(
            new AuthResponse(access, refresh, user.Id, user.UserName!, user.Email!, role));
    }

    private static bool CryptographicEquals(string a, string b)
    {
        if (a.Length != b.Length) return false;
        var diff = 0;
        for (var i = 0; i < a.Length; i++)
            diff |= a[i] ^ b[i];
        return diff == 0;
    }
}
