using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Inkril.Application.Common.Interfaces;
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
    private static readonly TimeSpan RefreshTokenLifetime = TimeSpan.FromDays(7);

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

        // Rotate: delete any existing refresh tokens for this user before issuing a new one.
        // This prevents an old stolen token from being valid after a fresh login.
        var oldTokens = await db.RefreshTokens
            .Where(rt => rt.UserId == user.Id)
            .ToListAsync();
        db.RefreshTokens.RemoveRange(oldTokens);

        var refreshTokenValue = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        var refreshToken = new RefreshToken
        {
            UserId = user.Id,
            Token = refreshTokenValue,
            ExpiresAt = DateTime.UtcNow.Add(RefreshTokenLifetime),
        };
        db.RefreshTokens.Add(refreshToken);
        await db.SaveChangesAsync();

        return (accessToken, refreshTokenValue);
    }

    public async Task<ApplicationUser?> ValidateRefreshTokenAsync(string refreshToken)
    {
        var row = await db.RefreshTokens
            .Include(rt => rt.User)
            .FirstOrDefaultAsync(rt =>
                rt.Token == refreshToken &&
                !rt.IsRevoked &&
                rt.ExpiresAt > DateTime.UtcNow);

        return row?.User;
    }

    public async Task RevokeRefreshTokenAsync(ApplicationUser user)
    {
        var tokens = await db.RefreshTokens
            .Where(rt => rt.UserId == user.Id)
            .ToListAsync();
        db.RefreshTokens.RemoveRange(tokens);
        await db.SaveChangesAsync();
    }
}
