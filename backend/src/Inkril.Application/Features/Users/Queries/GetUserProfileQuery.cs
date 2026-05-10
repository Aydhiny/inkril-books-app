using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Users.Queries;

public record DailyStatDto(DateOnly Date, int MinutesRead);

public record UserProfileDto(
    Guid Id,
    string UserName,
    string Email,
    string FirstName,
    string LastName,
    string? ProfilePhotoUrl,
    string? Bio,
    int CurrentStreak,
    double TotalReadingHours,
    int FriendCount,
    int BooksRead,
    IEnumerable<DailyStatDto> WeeklyStats,
    int YearlyBookGoal,
    int YearlyBooksRead);

public record GetUserProfileQuery(Guid UserId) : IRequest<Result<UserProfileDto>>;

public class GetUserProfileQueryHandler(
    UserManager<ApplicationUser> userManager,
    IUnitOfWork uow)
    : IRequestHandler<GetUserProfileQuery, Result<UserProfileDto>>
{
    public async Task<Result<UserProfileDto>> Handle(GetUserProfileQuery q, CancellationToken ct)
    {
        var user = await userManager.FindByIdAsync(q.UserId.ToString());
        if (user is null || user.IsDeleted)
            return Result<UserProfileDto>.Failure("User not found.");

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var weekStart = today.AddDays(-6);

        var stats = await uow.DailyReadingStats.FindAsync(
            s => s.UserId == q.UserId, ct);

        var statsList = stats.ToList();

        var totalMinutes = statsList.Sum(s => s.MinutesRead);
        var booksRead = statsList.Sum(s => s.BooksCompleted);
        var currentStreak = statsList
            .Where(s => s.Date == today)
            .Select(s => s.StreakDays)
            .FirstOrDefault();

        var weeklyStats = Enumerable.Range(0, 7)
            .Select(i => today.AddDays(-6 + i))
            .Select(date => new DailyStatDto(
                date,
                statsList.FirstOrDefault(s => s.Date == date)?.MinutesRead ?? 0))
            .ToList();

        var friendCount = await uow.Friendships.CountAsync(
            f => f.UserId == q.UserId, ct);

        // Yearly goal — from UserSettings (0 means no goal set)
        var settings = (await uow.UserSettings.FindAsync(s => s.UserId == q.UserId, ct)).FirstOrDefault();
        var yearlyBookGoal = settings?.YearlyBookGoal ?? 0;

        // Books completed this calendar year
        var yearStart = new DateOnly(today.Year, 1, 1);
        var yearlyBooksRead = statsList
            .Where(s => s.Date >= yearStart)
            .Sum(s => s.BooksCompleted);

        return Result<UserProfileDto>.Success(new UserProfileDto(
            user.Id,
            user.UserName!,
            user.Email!,
            user.FirstName,
            user.LastName,
            user.ProfilePhotoUrl,
            user.Bio,
            currentStreak,
            Math.Round(totalMinutes / 60.0, 1),
            friendCount,
            booksRead,
            weeklyStats,
            yearlyBookGoal,
            yearlyBooksRead));
    }
}
