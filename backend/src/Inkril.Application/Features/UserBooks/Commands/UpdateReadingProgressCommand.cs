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

        if (userBook is null)
        {
            userBook = new UserBook
            {
                UserId = userId,
                BookId = cmd.BookId,
                CreatedBy = userId.ToString()
            };
            await uow.UserBooks.AddAsync(userBook, ct);
        }

        userBook.LastReadPageNumber = cmd.CurrentPage;
        userBook.LastReadAt = DateTime.UtcNow;

        userBook.ReadingProgressPercent = book.TotalPages > 0
            ? Math.Round((double)cmd.CurrentPage / book.TotalPages * 100, 1)
            : 0;

        if (userBook.ReadingProgressPercent >= 100)
            userBook.MarkCompleted();

        userBook.UpdatedAt = DateTime.UtcNow;
        uow.UserBooks.Update(userBook);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
