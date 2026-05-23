using Microsoft.AspNetCore.Identity;

namespace Inkril.Domain.Entities;

/// <summary>
/// Extends IdentityUser with Inkril-specific profile fields.
/// ASP.NET Identity tables (AspNetUsers, AspNetRoles, etc.) are reference tables
/// and do NOT count toward the 10-table minimum.
/// </summary>
public class ApplicationUser : IdentityUser<Guid>
{
    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string? ProfilePhotoUrl { get; set; }

    public string? Bio { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }

    public bool IsDeleted { get; set; } = false;

    public bool IsBlocked { get; set; } = false;

    /// <summary>
    /// Stripe Customer ID (cus_…). Populated on first payment interaction.
    /// Null until the user initiates a purchase or saves a payment method.
    /// </summary>
    public string? StripeCustomerId { get; set; }

    // Navigation properties
    public UserSettings? Settings { get; set; }
    public ICollection<UserBook> UserBooks { get; set; } = [];
    public ICollection<ReadingSession> ReadingSessions { get; set; } = [];
    public ICollection<Bookmark> Bookmarks { get; set; } = [];
    public ICollection<Review> Reviews { get; set; } = [];
    public ICollection<Notification> Notifications { get; set; } = [];
    public ICollection<DailyReadingStat> DailyReadingStats { get; set; } = [];
    public ICollection<Friendship> Friendships { get; set; } = [];
    public ICollection<FriendRequest> SentFriendRequests { get; set; } = [];
    public ICollection<FriendRequest> ReceivedFriendRequests { get; set; } = [];
}
