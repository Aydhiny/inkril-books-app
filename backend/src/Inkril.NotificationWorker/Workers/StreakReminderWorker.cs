using Inkril.NotificationWorker.Services;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Inkril.NotificationWorker.Workers;

/// <summary>
/// Runs once per day at 20:00 UTC and creates in-app notifications for every
/// user who has an active streak (> 0 days) but has NOT read anything today.
/// This is the "🔥 Your streak is at risk" reminder.
/// </summary>
public class StreakReminderWorker(
    ILogger<StreakReminderWorker> logger,
    IServiceProvider services) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("StreakReminderWorker started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            var now      = DateTime.UtcNow;
            // Fire at 20:00 UTC every day (adjustable via env var in a real project)
            var nextFire = new DateTime(now.Year, now.Month, now.Day, 20, 0, 0, DateTimeKind.Utc);
            if (now >= nextFire) nextFire = nextFire.AddDays(1);

            var delay = nextFire - now;
            logger.LogInformation("StreakReminderWorker next run in {Delay:hh\\:mm\\:ss}", delay);

            try { await Task.Delay(delay, stoppingToken); }
            catch (OperationCanceledException) { break; }

            await SendStreakRemindersAsync(stoppingToken);
        }

        logger.LogInformation("StreakReminderWorker stopped.");
    }

    private async Task SendStreakRemindersAsync(CancellationToken ct)
    {
        logger.LogInformation("Running daily streak reminder check…");
        try
        {
            using var scope   = services.CreateScope();
            var dbService     = scope.ServiceProvider.GetRequiredService<INotificationDbService>();
            var usersAtRisk   = await dbService.GetUsersAtStreakRiskAsync();

            var count = 0;
            foreach (var (userId, streakDays) in usersAtRisk)
            {
                await dbService.CreateNotificationAsync(
                    userId:      userId,
                    type:        "StreakReminder",
                    title:       "Your streak is at risk! 🔥",
                    message:     $"You haven't read today. Your {streakDays}-day streak will reset at midnight — open a book to keep it alive!");
                count++;
            }

            logger.LogInformation("Sent streak reminder to {Count} users.", count);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "StreakReminderWorker failed.");
        }
    }
}
