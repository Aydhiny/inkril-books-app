using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Table 10 of 10 — aggregated daily reading stats per user.
/// Populated at session end; drives the streak counter, leaderboard,
/// and the weekly reading chart in the profile screen.
/// </summary>
public class DailyReadingStat : BaseEntity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public DateOnly Date { get; set; }

    public int MinutesRead { get; set; } = 0;

    public int PagesRead { get; set; } = 0;

    public int BooksCompleted { get; set; } = 0;

    /// <summary>Streak counter as of this day — stored for fast leaderboard queries.</summary>
    public int StreakDays { get; set; } = 0;
}
