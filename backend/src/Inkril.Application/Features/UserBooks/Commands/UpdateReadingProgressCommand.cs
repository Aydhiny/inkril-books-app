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
/// <param name="TotalPdfPages">Actual page count reported by the PDF renderer.
/// When provided and > 0, used instead of <c>book.TotalPages</c> so progress
/// is always accurate even when the DB value is 0 or stale.</param>
public record UpdateReadingProgressCommand(
    Guid UserId, Guid BookId, int CurrentPage, int? TotalPdfPages = null) : IRequest<Result>;

public class UpdateReadingProgressCommandValidator : AbstractValidator<UpdateReadingProgressCommand>
{
    public UpdateReadingProgressCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.BookId).NotEmpty();
        RuleFor(x => x.CurrentPage).GreaterThanOrEqualTo(0);
    }
}

public class UpdateReadingProgressCommandHandler(IUnitOfWork uow)
    : IRequestHandler<UpdateReadingProgressCommand, Result>
{
    public async Task<Result> Handle(UpdateReadingProgressCommand cmd, CancellationToken ct)
    {
        var book = await uow.Books.GetByIdAsync(cmd.BookId, ct);
        if (book is null) return Result.Failure("Book not found.");

        var userBook = await uow.UserBooks.FirstOrDefaultAsync(
            ub => ub.UserId == cmd.UserId && ub.BookId == cmd.BookId, ct);

        if (userBook is null)
        {
            userBook = new UserBook
            {
                UserId = cmd.UserId,
                BookId = cmd.BookId,
                CreatedBy = cmd.UserId.ToString()
            };
            await uow.UserBooks.AddAsync(userBook, ct);
        }

        userBook.LastReadPageNumber = cmd.CurrentPage;
        userBook.LastReadAt = DateTime.UtcNow;

        // Prefer the actual PDF page count sent by the client over the DB value,
        // which can be 0 (uploaded books) or a full-book count while the PDF is a preview.
        var denominator = (cmd.TotalPdfPages is > 0) ? cmd.TotalPdfPages.Value : book.TotalPages;
        userBook.ReadingProgressPercent = denominator > 0
            ? Math.Round((double)cmd.CurrentPage / denominator * 100, 1)
            : 0;

        if (userBook.ReadingProgressPercent >= 100 && !userBook.IsCompleted)
        {
            userBook.IsCompleted = true;
            userBook.CompletedAt = DateTime.UtcNow;
        }

        userBook.UpdatedAt = DateTime.UtcNow;
        uow.UserBooks.Update(userBook);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
