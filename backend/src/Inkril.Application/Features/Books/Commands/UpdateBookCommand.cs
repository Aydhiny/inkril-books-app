using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

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
        var book = await uow.Books.GetByIdAsync(cmd.Id, ct);
        if (book is null || book.IsDeleted)
            return Result.Failure("Book not found.");

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

        uow.Books.Update(book);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
