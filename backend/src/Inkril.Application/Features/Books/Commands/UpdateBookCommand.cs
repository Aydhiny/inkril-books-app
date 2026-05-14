using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Books.Commands;

public record UpdateBookCommand(
    Guid Id,
    string Title,
    string Author,
    string? Description,
    string? CoverImageUrl,
    int TotalPages,
    DateTime PublishedDate,
    string? ISBN,
    string? Publisher,
    bool IsPublic,
    IEnumerable<Guid> GenreIds
) : IRequest<Result>;

public class UpdateBookCommandValidator : AbstractValidator<UpdateBookCommand>
{
    public UpdateBookCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Title).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Author).NotEmpty().MaximumLength(200);
        RuleFor(x => x.TotalPages).GreaterThan(0);
    }
}

public class UpdateBookCommandHandler(IUnitOfWork uow, ICurrentUserService currentUser)
    : IRequestHandler<UpdateBookCommand, Result>
{
    public async Task<Result> Handle(UpdateBookCommand cmd, CancellationToken ct)
    {
        // Load with BookGenres included so EF change-tracker knows the current genre set
        // and can diff it against the new set on SaveChanges.
        var book = await uow.Books.Query()
            .Include(b => b.BookGenres)
            .FirstOrDefaultAsync(b => b.Id == cmd.Id && !b.IsDeleted, ct);

        if (book is null)
            return Result.Failure("Book not found.");

        // Validate that every submitted GenreId actually exists — silently saving with
        // missing genres would confuse the admin (§22 in the professor's code review notes).
        var requestedIds = cmd.GenreIds.Distinct().ToList();
        if (requestedIds.Count > 0)
        {
            var foundCount = await uow.Genres.CountAsync(
                g => requestedIds.Contains(g.Id) && !g.IsDeleted, ct);
            if (foundCount != requestedIds.Count)
                return Result.Failure("One or more of the submitted genre IDs do not exist.");
        }

        book.Title = cmd.Title;
        book.Author = cmd.Author;
        book.Description = cmd.Description;
        book.CoverImageUrl = cmd.CoverImageUrl;
        book.TotalPages = cmd.TotalPages;
        book.PublishedDate = cmd.PublishedDate;
        book.ISBN = cmd.ISBN;
        book.Publisher = cmd.Publisher;
        book.IsPublic = cmd.IsPublic;
        book.UpdatedAt = DateTime.UtcNow;
        book.UpdatedBy = currentUser.UserName;

        // Replace genre assignments — EF change-tracker handles DELETE + INSERT diffing.
        // Previously this block was missing, so genre changes were silently discarded.
        book.BookGenres.Clear();
        foreach (var gid in requestedIds)
            book.BookGenres.Add(new BookGenre { BookId = book.Id, GenreId = gid });

        uow.Books.Update(book);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
