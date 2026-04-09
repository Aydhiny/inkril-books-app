using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;

namespace Inkril.Application.Features.Bookmarks.Commands;

public record CreateBookmarkCommand(
    Guid UserId,
    Guid BookId,
    int PageNumber,
    string? HighlightedText,
    string? Note,
    string? Color
) : IRequest<Result<Guid>>;

public class CreateBookmarkCommandValidator : AbstractValidator<CreateBookmarkCommand>
{
    public CreateBookmarkCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.BookId).NotEmpty();
        RuleFor(x => x.PageNumber).GreaterThan(0).WithMessage("Page number must be greater than 0.");
        RuleFor(x => x.HighlightedText).MaximumLength(2000).When(x => x.HighlightedText != null);
        RuleFor(x => x.Note).MaximumLength(1000).When(x => x.Note != null);
    }
}

public class CreateBookmarkCommandHandler(IUnitOfWork uow)
    : IRequestHandler<CreateBookmarkCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateBookmarkCommand cmd, CancellationToken ct)
    {
        var book = await uow.Books.GetByIdAsync(cmd.BookId, ct);
        if (book is null) return Result<Guid>.Failure("Book not found.");

        var bookmark = new Bookmark
        {
            UserId = cmd.UserId,
            BookId = cmd.BookId,
            PageNumber = cmd.PageNumber,
            HighlightedText = cmd.HighlightedText,
            Note = cmd.Note,
            Color = cmd.Color ?? "#FFD700",
            CreatedBy = cmd.UserId.ToString()
        };

        await uow.Bookmarks.AddAsync(bookmark, ct);
        await uow.SaveChangesAsync(ct);

        return Result<Guid>.Success(bookmark.Id);
    }
}
