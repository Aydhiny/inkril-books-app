using Inkril.Domain.Entities;

namespace Inkril.Application.Common.Interfaces;

public interface ITokenService
{
    Task<(string AccessToken, string RefreshToken)> GenerateTokensAsync(ApplicationUser user);
    Task<ApplicationUser?> ValidateRefreshTokenAsync(string refreshToken);
    Task RevokeRefreshTokenAsync(ApplicationUser user);
}
