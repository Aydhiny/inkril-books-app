using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Table 9 of 10 — per-user preferences and notification opt-ins.
/// One-to-one with ApplicationUser.
/// </summary>
public class UserSettings : BaseEntity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public bool ReceiveNewBookNotifications { get; set; } = true;

    public bool ReceiveFriendActivityNotifications { get; set; } = true;

    public bool ReceiveWeeklySummaryEmail { get; set; } = true;

    /// <summary>Daily reading goal in minutes.</summary>
    public int DailyReadingGoalMinutes { get; set; } = 30;

    public string Theme { get; set; } = "system";

    public string Language { get; set; } = "en";

    /// <summary>How many books the user wants to read this calendar year. 0 = no goal set.</summary>
    public int YearlyBookGoal { get; set; } = 0;
}

