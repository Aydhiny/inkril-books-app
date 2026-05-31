using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.UserSettings.Queries;

public record GetUserSettingsQuery : IRequest<Result<UserSettingsDto>>;

public record UserSettingsDto(
    bool NotificationsEnabled,
    bool FriendActivityNotifications,
    bool WeeklySummaryEmail,
    int DailyReadingGoalMinutes,
    string Theme,
    string Language,
    int YearlyBookGoal
);

public class GetUserSettingsQueryHandler(
    IUnitOfWork uow,
    ICurrentUserService currentUser,
    UserManager<ApplicationUser> userManager)
    : IRequestHandler<GetUserSettingsQuery, Result<UserSettingsDto>>
{
    public async Task<Result<UserSettingsDto>> Handle(
        GetUserSettingsQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUser.UserId
            ?? throw new UnauthorizedAccessException();

        // Guard: the JWT may outlive a DB reset (stale token for a deleted account).
        // Attempting to auto-create UserSettings for a non-existent AspNetUsers row
        // violates the FK constraint and produces a 500. Return a clean 404 instead.
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null || user.IsDeleted)
            return Result<UserSettingsDto>.Failure("User not found.");

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
            settings.Language,
            settings.YearlyBookGoal
        ));
    }
}
