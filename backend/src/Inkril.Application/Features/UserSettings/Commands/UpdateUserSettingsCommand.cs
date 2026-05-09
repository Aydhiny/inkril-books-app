using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.UserSettings.Commands;

public record UpdateUserSettingsCommand(
    bool NotificationsEnabled,
    bool FriendActivityNotifications,
    bool WeeklySummaryEmail,
    int DailyReadingGoalMinutes,
    string Theme,
    string Language
) : IRequest<Result>;

public class UpdateUserSettingsCommandHandler(
    IUnitOfWork uow,
    ICurrentUserService currentUser)
    : IRequestHandler<UpdateUserSettingsCommand, Result>
{
    public async Task<Result> Handle(
        UpdateUserSettingsCommand cmd, CancellationToken cancellationToken)
    {
        var userId = currentUser.UserId
            ?? throw new UnauthorizedAccessException();

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
        settings.UpdatedAt                          = DateTime.UtcNow;

        uow.UserSettings.Update(settings);
        await uow.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }
}
