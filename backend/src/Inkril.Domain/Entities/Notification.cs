using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

public enum NotificationType
{
    NewBook               = 0,
    FriendRequest         = 1,
    FriendRequestAccepted = 2,
    FriendReadingMilestone = 3,
    WeeklyReadingSummary  = 4,
    System                = 5,
    StreakReminder        = 6,
    FriendRequestRejected = 7,
}

/// <summary>
/// Table 8 of 10 — in-app notification for a user.
/// Records are created by the main API and can also be triggered by
/// the NotificationWorker after consuming RabbitMQ messages.
/// </summary>
public class Notification : BaseEntity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public NotificationType Type { get; set; }

    public string Title { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public bool IsRead { get; set; } = false;

    public DateTime? ReadAt { get; set; }

    /// <summary>Optional reference to the entity that triggered this notification.</summary>
    public Guid? ReferenceId { get; set; }
}
