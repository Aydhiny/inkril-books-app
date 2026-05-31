using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.UserSettings.Commands;

public record UpdateUserSettingsCommand(
    bool NotificationsEnabled,
    bool FriendActivityNotifications,
    bool WeeklySummaryEmail,
    int DailyReadingGoalMinutes,
    string Theme,
    string Language,
    int YearlyBookGoal = 0
) : IRequest<Result>;

public class UpdateUserSettingsCommandHandler(
    IUnitOfWork uow,
    ICurrentUserService currentUser,
    UserManager<ApplicationUser> userManager)
    : IRequestHandler<UpdateUserSettingsCommand, Result>
{
    public async Task<Result> Handle(
        UpdateUserSettingsCommand cmd, CancellationToken cancellationToken)
    {
        var userId = currentUser.UserId
            ?? throw new UnauthorizedAccessException();

        // Same guard as GetUserSettingsQuery: reject stale JWTs for deleted accounts
        // before attempting any write so we never create orphaned FK rows.
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null || user.IsDeleted)
            return Result.Failure("User not found.");

        var settings = await uow.UserSettings
            .FirstOrDefaultAsync(s => s.UserId == userId, cancellationToken);

        if (settings is null)
        {
            settings = new Inkril.Domain.Entities.UserSettings { UserId = userId };
            await uow.UserSettings.AddAsync(settings, cancellationToken);
        }

        settings.ReceiveNewBookNotifications        = cmd.NotificationsEnabled;
        settings.ReceiveFriendActivityNotifications = cmd.FriendActivityNotifications;
        settings.ReceiveWeeklySummaryEmail          = cmd.WeeklySummaryEmail;
        settings.DailyReadingGoalMinutes            = cmd.DailyReadingGoalMinutes;
        settings.Theme                              = cmd.Theme;
        settings.Language                           = cmd.Language;
        settings.YearlyBookGoal                     = cmd.YearlyBookGoal;
        settings.UpdatedAt                          = DateTime.UtcNow;

        uow.UserSettings.Update(settings);
        await uow.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }
}
