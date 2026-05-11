using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Inkril.Application.Features.Auth.Commands;
using Inkril.Domain.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Inkril.Infrastructure.Services;

public class TokenService(
    IConfiguration config,
    UserManager<ApplicationUser> userManager) : ITokenService
{
    public async Task<(string AccessToken, string RefreshToken)> GenerateTokensAsync(ApplicationUser user)
    {
        var roles = await userManager.GetRolesAsync(user);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.UserName!),
            new(ClaimTypes.Email, user.Email!),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };
        claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));

        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(config["Jwt:Key"] ?? throw new InvalidOperationException("Jwt:Key not configured")));

        var token = new JwtSecurityToken(
            issuer: config["Jwt:Issuer"],
            audience: config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(double.Parse(config["Jwt:ExpiryMinutes"] ?? "60")),
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));

        var accessToken = new JwtSecurityTokenHandler().WriteToken(token);
        var refreshToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));

        // Store refresh token in user (simple approach — for production use a dedicated RefreshToken table)
        await userManager.SetAuthenticationTokenAsync(user, "Inkril", "RefreshToken", refreshToken);

        return (accessToken, refreshToken);
    }

    public async Task<ApplicationUser?> ValidateRefreshTokenAsync(string refreshToken)
    {
        // Find user by stored refresh token
        var users = userManager.Users.ToList();
        foreach (var user in users)
        {
            var stored = await userManager.GetAuthenticationTokenAsync(user, "Inkril", "RefreshToken");
            if (stored == refreshToken)
                return user;
        }
        return null;
    }

    public async Task RevokeRefreshTokenAsync(ApplicationUser user)
    {
        // Removing the stored token means any subsequent refresh attempt will fail —
        // effectively invalidating the session server-side (§5 requirement).
        await userManager.RemoveAuthenticationTokenAsync(user, "Inkril", "RefreshToken");
    }
}
