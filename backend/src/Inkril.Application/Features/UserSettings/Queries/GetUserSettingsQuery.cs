using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.UserSettings.Queries;

public record GetUserSettingsQuery : IRequest<Result<UserSettingsDto>>;

public record UserSettingsDto(
    bool NotificationsEnabled,
    bool FriendActivityNotifications,
    bool WeeklySummaryEmail,
    int DailyReadingGoalMinutes,
    string Theme,
    string Language
);

public class GetUserSettingsQueryHandler(
    IUnitOfWork uow,
    ICurrentUserService currentUser)
    : IRequestHandler<GetUserSettingsQuery, Result<UserSettingsDto>>
{
    public async Task<Result<UserSettingsDto>> Handle(
        GetUserSettingsQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUser.UserId
            ?? throw new UnauthorizedAccessException();

        var settings = await uow.UserSettings
            .FirstOrDefaultAsync(s => s.UserId == userId, cancellationToken);

        if (settings is null)
        {
            // Auto-create default settings on first access
            settings = new Inkril.Domain.Entities.UserSettings { UserId = userId };
            await uow.UserSettings.AddAsync(settings, cancellationToken);
            await uow.SaveChangesAsync(cancellationToken);
        }

        return Result<UserSettingsDto>.Success(new UserSettingsDto(
            settings.ReceiveNewBookNotifications,
            settings.ReceiveFriendActivityNotifications,
            settings.ReceiveWeeklySummaryEmail,
            settings.DailyReadingGoalMinutes,
            settings.Theme,
            settings.Language
        ));
    }
}
