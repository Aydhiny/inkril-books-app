using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Table 6 of 10 — a confirmed friendship between two users.
/// Created when a FriendRequest is accepted.
/// </summary>
public class Friendship : BaseEntity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public Guid FriendId { get; set; }
    public ApplicationUser Friend { get; set; } = null!;

    public DateTime FriendsSince { get; set; } = DateTime.UtcNow;
}
