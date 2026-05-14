using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Inkril.Application.Features.Auth.Commands;
using Inkril.Domain.Entities;
using Inkril.Infrastructure.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Inkril.Infrastructure.Services;

public class TokenService(
    IConfiguration config,
    UserManager<ApplicationUser> userManager,
    InkrilDbContext db) : ITokenService
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
        // Query AspNetUserTokens directly — one indexed lookup instead of loading
        // all users into memory and iterating (previous approach was an O(n) full
        // table scan that would block the thread pool under load).
        var tokenRow = await db.UserTokens
            .Where(t => t.LoginProvider == "Inkril"
                     && t.Name == "RefreshToken"
                     && t.Value == refreshToken)
            .Select(t => t.UserId)
            .FirstOrDefaultAsync();

        if (tokenRow == default) return null;

        return await userManager.FindByIdAsync(tokenRow.ToString());
    }

    public async Task RevokeRefreshTokenAsync(ApplicationUser user)
    {
        // Removing the stored token means any subsequent refresh attempt will fail —
        // effectively invalidating the session server-side (§5 requirement).
        await userManager.RemoveAuthenticationTokenAsync(user, "Inkril", "RefreshToken");
    }
}
