using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;


namespace Inkril.Application.Features.UserBooks.Commands;

/// <summary>
/// Lightweight mid-session progress update — called by the reader on page turns (debounced).
/// Does NOT create or end a ReadingSession; it just persists the current page position so
/// that if the app is force-killed the user still resumes from the last synced page.
/// </summary>
public record UpdateReadingProgressCommand(Guid BookId, int CurrentPage) : IRequest<Result>;

public class UpdateReadingProgressCommandValidator : AbstractValidator<UpdateReadingProgressCommand>
{
    public UpdateReadingProgressCommandValidator()
    {
        RuleFor(x => x.BookId).NotEmpty();
        RuleFor(x => x.CurrentPage).GreaterThanOrEqualTo(0);
    }
}

public class UpdateReadingProgressCommandHandler(IUnitOfWork uow, ICurrentUserService currentUser)
    : IRequestHandler<UpdateReadingProgressCommand, Result>
{
    public async Task<Result> Handle(UpdateReadingProgressCommand cmd, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();

        var book = await uow.Books.GetByIdAsync(cmd.BookId, ct);
        if (book is null) return Result.Failure("Book not found.");

        var userBook = await uow.UserBooks.FirstOrDefaultAsync(
            ub => ub.UserId == userId && ub.BookId == cmd.BookId, ct);

        // Do NOT auto-create a UserBook here. The user must have explicitly added the
        // book via AddBookToLibraryCommand (which enforces the premium purchase gate).
        // Auto-creating a UserBook would bypass the access check in GetBookReadUrlQuery.
        if (userBook is null)
            return Result.Failure("Book is not in your library. Add it first.");

        if (book.TotalPages > 0 && cmd.CurrentPage > book.TotalPages)
            return Result.Failure($"Page {cmd.CurrentPage} exceeds the book's total pages ({book.TotalPages}).");

        userBook.LastReadPageNumber = cmd.CurrentPage;
        userBook.LastReadAt = DateTime.UtcNow;

        userBook.ReadingProgressPercent = book.TotalPages > 0
            ? Math.Min(100, Math.Round((double)cmd.CurrentPage / book.TotalPages * 100, 1))
            : 0;

        var wasAlreadyCompleted = userBook.IsCompleted;
        if (userBook.ReadingProgressPercent >= 100)
            userBook.MarkCompleted();

        userBook.UpdatedAt = DateTime.UtcNow;
        uow.UserBooks.Update(userBook);
        await uow.SaveChangesAsync(ct);

        if (!wasAlreadyCompleted && userBook.IsCompleted)
        {
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var stat = await uow.DailyReadingStats.FirstOrDefaultAsync(
                s => s.UserId == userId && s.Date == today, ct);
            if (stat is not null)
            {
                stat.BooksCompleted++;
                stat.UpdatedAt = DateTime.UtcNow;
                uow.DailyReadingStats.Update(stat);
                await uow.SaveChangesAsync(ct);
            }
        }

        return Result.Success();
    }
}
