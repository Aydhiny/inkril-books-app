using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

public enum FriendRequestStatus { Pending, Accepted, Rejected }

/// <summary>
/// Table 7 of 10 — a pending or processed friend request.
/// On acceptance a Friendship record is created and a notification is sent via RabbitMQ.
/// </summary>
public class FriendRequest : BaseEntity
{
    public Guid SenderId { get; set; }
    public ApplicationUser Sender { get; set; } = null!;

    public Guid ReceiverId { get; set; }
    public ApplicationUser Receiver { get; set; } = null!;

    public FriendRequestStatus Status { get; set; } = FriendRequestStatus.Pending;

    public DateTime? RespondedAt { get; set; }
}
