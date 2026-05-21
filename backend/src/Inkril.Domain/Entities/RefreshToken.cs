namespace Inkril.Domain.Entities;

/// <summary>
/// Persisted refresh token — intentionally NOT a BaseEntity because tokens are
/// infrastructure secrets, not auditable domain objects. They have a fixed TTL
/// and are hard-deleted on rotation or revocation.
/// </summary>
public class RefreshToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;
    public string Token { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public bool IsRevoked { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
