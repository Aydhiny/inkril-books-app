using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.ReadingSessions.Commands;

public record EndReadingSessionCommand(Guid SessionId, int EndPage) : IRequest<Result>;

public class EndReadingSessionCommandValidator : AbstractValidator<EndReadingSessionCommand>
{
    public EndReadingSessionCommandValidator()
    {
        RuleFor(x => x.SessionId).NotEmpty();
        RuleFor(x => x.EndPage).GreaterThanOrEqualTo(0);
    }
}

public class EndReadingSessionCommandHandler(
    IUnitOfWork uow,
    IMessagePublisher publisher,
    ICurrentUserService currentUser)
    : IRequestHandler<EndReadingSessionCommand, Result>
{
    public async Task<Result> Handle(EndReadingSessionCommand cmd, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var session = await uow.ReadingSessions.GetByIdAsync(cmd.SessionId, ct);
        if (session is null || session.UserId != userId)
            return Result.Failure("Reading session not found.");

        if (session.EndedAt.HasValue)
            return Result.Failure("Session already ended.");

        session.EndedAt = DateTime.UtcNow;
        session.EndPage = cmd.EndPage;
        session.DurationMinutes = (int)(session.EndedAt.Value - session.StartedAt).TotalMinutes;
        session.UpdatedAt = DateTime.UtcNow;
        uow.ReadingSessions.Update(session);

        await UpdateUserBookProgressAsync(session, ct);
        var streakDays = await UpsertDailyStatAsync(session, ct);
        await uow.SaveChangesAsync(ct);

        var milestones = new[] { 30, 60, 120 };
        var totalToday = await GetTodayMinutesAsync(userId, ct);
        foreach (var milestone in milestones)
        {
            if (totalToday - session.DurationMinutes < milestone && totalToday >= milestone)
            {
                await publisher.PublishAsync(
                    new { UserId = userId, Milestone = $"{milestone}-minute reading goal", StreakDays = streakDays },
                    routingKey: "reading.milestone", ct);
                break;
            }
        }

        return Result.Success();
    }

    private async Task UpdateUserBookProgressAsync(ReadingSession session, CancellationToken ct)
    {
        var book = await uow.Books.GetByIdAsync(session.BookId, ct);
        if (book is null) return;

        var userBook = await uow.UserBooks.FirstOrDefaultAsync(
            ub => ub.UserId == session.UserId && ub.BookId == session.BookId, ct);

        if (userBook is null)
        {
            userBook = new UserBook { UserId = session.UserId, BookId = session.BookId };
            await uow.UserBooks.AddAsync(userBook, ct);
        }

        userBook.LastReadPageNumber = session.EndPage;
        userBook.LastReadAt = session.EndedAt;

        userBook.ReadingProgressPercent = book.TotalPages > 0
            ? Math.Round((double)session.EndPage / book.TotalPages * 100, 1)
            : 0;

        if (userBook.ReadingProgressPercent >= 100)
            userBook.MarkCompleted();

        userBook.UpdatedAt = DateTime.UtcNow;
        uow.UserBooks.Update(userBook);
    }

    private async Task<int> UpsertDailyStatAsync(ReadingSession session, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var yesterday = today.AddDays(-1);

        var stat = await uow.DailyReadingStats.FirstOrDefaultAsync(
            s => s.UserId == session.UserId && s.Date == today, ct);

        var yesterdayStat = await uow.DailyReadingStats.FirstOrDefaultAsync(
            s => s.UserId == session.UserId && s.Date == yesterday, ct);

        var streak = yesterdayStat != null ? yesterdayStat.StreakDays + 1 : 1;

        if (stat is null)
        {
            stat = new DailyReadingStat
            {
                UserId = session.UserId,
                Date = today,
                MinutesRead = session.DurationMinutes,
                PagesRead = session.PagesRead,
                StreakDays = streak,
                CreatedBy = session.UserId.ToString()
            };
            await uow.DailyReadingStats.AddAsync(stat, ct);
        }
        else
        {
            stat.MinutesRead += session.DurationMinutes;
            stat.PagesRead += session.PagesRead;
            stat.StreakDays = streak;
            stat.UpdatedAt = DateTime.UtcNow;
            uow.DailyReadingStats.Update(stat);
        }

        return streak;
    }

    private async Task<int> GetTodayMinutesAsync(Guid userId, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var stat = await uow.DailyReadingStats.FirstOrDefaultAsync(
            s => s.UserId == userId && s.Date == today, ct);
        return stat?.MinutesRead ?? 0;
    }
}
