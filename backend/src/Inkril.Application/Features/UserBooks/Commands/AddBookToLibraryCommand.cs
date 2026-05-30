using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using Inkril.Domain.Enums;
using MediatR;

namespace Inkril.Application.Features.UserBooks.Commands;

public record AddBookToLibraryCommand(Guid UserId, Guid BookId) : IRequest<Result<Guid>>;

public class AddBookToLibraryCommandValidator : AbstractValidator<AddBookToLibraryCommand>
{
    public AddBookToLibraryCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.BookId).NotEmpty();
    }
}

public class AddBookToLibraryCommandHandler(IUnitOfWork uow)
    : IRequestHandler<AddBookToLibraryCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(AddBookToLibraryCommand cmd, CancellationToken ct)
    {
        var book = await uow.Books.GetByIdAsync(cmd.BookId, ct);
        if (book is null) return Result<Guid>.Failure("Book not found.");

        // ── Premium gate ──────────────────────────────────────────────────────
        // Premium books may only be added to a library through the purchase flow
        // (ConfirmPurchaseCommand). Allowing free add would bypass the Stripe
        // payment check since GetBookReadUrlQuery only verifies UserBooks ownership,
        // not whether a purchase record exists.
        if (book.IsPremium)
        {
            var hasPurchase = await uow.Purchases.AnyAsync(
                p => p.UserId == cmd.UserId
                  && p.BookId == cmd.BookId
                  && p.Status == PurchaseStatus.Succeeded, ct);

            if (!hasPurchase)
                return Result<Guid>.Failure(
                    "This is a premium book. Purchase it first to add it to your library.");
        }

        var alreadyAdded = await uow.UserBooks.AnyAsync(
            ub => ub.UserId == cmd.UserId && ub.BookId == cmd.BookId, ct);
        if (alreadyAdded)
            return Result<Guid>.Failure("This book is already in your library.");

        var userBook = new UserBook
        {
            UserId = cmd.UserId,
            BookId = cmd.BookId,
            AddedAt = DateTime.UtcNow,
            CreatedBy = cmd.UserId.ToString()
        };

        await uow.UserBooks.AddAsync(userBook, ct);
        await uow.SaveChangesAsync(ct);

        return Result<Guid>.Success(userBook.Id);
    }
}
