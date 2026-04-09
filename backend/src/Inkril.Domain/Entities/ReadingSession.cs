using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Table 3 of 10 — a single reading session.
/// Used to calculate total reading time, daily streaks, and leaderboard scores.
/// </summary>
public class ReadingSession : BaseEntity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public Guid BookId { get; set; }
    public Book Book { get; set; } = null!;

    public DateTime StartedAt { get; set; } = DateTime.UtcNow;

    public DateTime? EndedAt { get; set; }

    /// <summary>Derived from EndedAt - StartedAt; stored for fast querying.</summary>
    public int DurationMinutes { get; set; } = 0;

    public int StartPage { get; set; }

    public int EndPage { get; set; }

    public int PagesRead => EndPage - StartPage;
}
