using Inkril.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Challenges;

// ── DTOs ──────────────────────────────────────────────────────────────────────

public record ChallengeDto(
    string Id,
    string Title,
    string Description,
    string Emoji,
    double Progress,   // 0.0 – 1.0
    int Current,
    int Target,
    string Unit,
    bool Completed,
    int XpReward
);

// ── Query ─────────────────────────────────────────────────────────────────────

public record GetChallengesQuery : IRequest<IEnumerable<ChallengeDto>>;

public class GetChallengesQueryHandler(
    IUnitOfWork uow,
    ICurrentUserService currentUser
) : IRequestHandler<GetChallengesQuery, IEnumerable<ChallengeDto>>
{
    public async Task<IEnumerable<ChallengeDto>> Handle(
        GetChallengesQuery _, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var today  = DateOnly.FromDateTime(DateTime.UtcNow);
        var monthStart = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1, 0, 0, 0, DateTimeKind.Utc);

        // ── Load raw data ─────────────────────────────────────────────────────

        var todayStat = await uow.DailyReadingStats.Query()
            .FirstOrDefaultAsync(d => d.UserId == userId && d.Date == today, ct);

        var settings = await uow.UserSettings.Query()
            .FirstOrDefaultAsync(s => s.UserId == userId, ct);

        var booksCompletedThisMonth = await uow.UserBooks.Query()
            .CountAsync(ub => ub.UserId == userId && ub.IsCompleted
                && ub.CompletedAt.HasValue && ub.CompletedAt >= monthStart, ct);

        var booksCompletedThisYear = await uow.UserBooks.Query()
            .CountAsync(ub => ub.UserId == userId && ub.IsCompleted
                && ub.CompletedAt.HasValue
                && ub.CompletedAt.Value.Year == DateTime.UtcNow.Year, ct);

        var currentStreak = todayStat?.StreakDays ?? 0;

        // ── Compute values ────────────────────────────────────────────────────

        var dailyGoalMinutes = settings?.DailyReadingGoalMinutes ?? 30;
        var yearlyGoal       = settings?.YearlyBookGoal ?? 0;
        var minutesToday     = todayStat?.MinutesRead ?? 0;
        var pagesToday       = todayStat?.PagesRead   ?? 0;

        // ── Build challenges ─────────────────────────────────────────────────

        var challenges = new List<ChallengeDto>
        {
            Build("daily-reader",
                "Daily Reader", $"Read for {dailyGoalMinutes} minutes today",
                "🕐", minutesToday, dailyGoalMinutes, "min", xp: 10),

            Build("century-pages",
                "Century Reader", "Read 100 pages today",
                "📄", pagesToday, 100, "pages", xp: 25),

            Build("monthly-finisher",
                "Monthly Bookworm", "Complete 3 books this month",
                "🐛", booksCompletedThisMonth, 3, "books", xp: 50),

            Build("streak-week",
                "Streak Keeper", "Maintain a 7-day reading streak",
                "🔥", currentStreak, 7, "days", xp: 30),
        };

        // Yearly goal only shown if one is set
        if (yearlyGoal > 0)
        {
            challenges.Add(Build("yearly-goal",
                $"{DateTime.UtcNow.Year} Reading Goal", $"Read {yearlyGoal} books this year",
                "🏆", booksCompletedThisYear, yearlyGoal, "books", xp: 100));
        }

        return challenges;
    }

    private static ChallengeDto Build(
        string id, string title, string desc, string emoji,
        int current, int target, string unit, int xp)
    {
        var clamped  = Math.Min(current, target);
        var progress = target > 0 ? (double)clamped / target : 0.0;
        return new ChallengeDto(id, title, desc, emoji, progress, clamped, target, unit, progress >= 1.0, xp);
    }
}
