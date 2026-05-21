using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Table 2 of 10 — a user's personal library entry.
/// Tracks which books a user has added and their reading progress.
/// </summary>
public class UserBook : BaseEntity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public Guid BookId { get; set; }
    public Book Book { get; set; } = null!;

    /// <summary>0–100 percent.</summary>
    public double ReadingProgressPercent { get; set; } = 0;

    public int LastReadPageNumber { get; set; } = 0;

    public DateTime? LastReadAt { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public bool IsCompleted { get; set; } = false;

    public DateTime? CompletedAt { get; set; }

    /// <summary>
    /// Marks the book as completed if it hasn't been already.
    /// Centralises completion logic so EndReadingSession and UpdateReadingProgress
    /// can't diverge over time.
    /// </summary>
    public void MarkCompleted()
    {
        if (IsCompleted) return;
        IsCompleted = true;
        CompletedAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
    }
}
