using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;

namespace Inkril.Application.Features.Books.Commands;

public record CreateBookCommand(
    string Title,
    string Author,
    string? Description,
    string? CoverImageUrl,
    /// <summary>
    /// Server-relative path for admin-uploaded books, or an absolute device path
    /// for local (IsLocal = true) books. Nullable because the PDF can be supplied
    /// later via POST /api/books/{id}/upload-pdf for admin-created books.
    /// </summary>
    string? FilePath,
    long FileSizeBytes = 0,
    int TotalPages = 0,
    DateTime PublishedDate = default,
    string? ISBN = null,
    string? Publisher = null,
    string? Language = "en",
    bool IsPublic = true,
    bool IsLocal = false,
    /// <summary>
    /// Nullable — local books don't belong to genres; admin books may omit genres on initial create.
    /// </summary>
    IEnumerable<Guid>? GenreIds = null
) : IRequest<Result<Guid>>;

public class CreateBookCommandValidator : AbstractValidator<CreateBookCommand>
{
    public CreateBookCommandValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Author).NotEmpty().MaximumLength(200);
        RuleFor(x => x.FilePath).MaximumLength(500).When(x => x.FilePath != null);
        RuleFor(x => x.TotalPages).GreaterThanOrEqualTo(0);
        // Local books are always private — silently coerce rather than rejecting.
        RuleFor(x => x.IsPublic).Equal(false).When(x => x.IsLocal)
            .WithMessage("Local books must be private (isPublic must be false).");
    }
}

public class CreateBookCommandHandler(
    IUnitOfWork uow,
    IMessagePublisher publisher,
    ICurrentUserService currentUser
) : IRequestHandler<CreateBookCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateBookCommand cmd, CancellationToken ct)
    {
        var book = new Book
        {
            Title         = cmd.Title,
            Author        = cmd.Author,
            Description   = cmd.Description,
            CoverImageUrl = cmd.CoverImageUrl,
            FilePath      = cmd.FilePath ?? string.Empty,
            FileSizeBytes = cmd.FileSizeBytes,
            TotalPages    = cmd.TotalPages,
            PublishedDate = cmd.PublishedDate == default ? DateTime.UtcNow : cmd.PublishedDate,
            ISBN          = cmd.ISBN,
            Publisher     = cmd.Publisher,
            Language      = cmd.Language ?? "en",
            IsPublic      = cmd.IsLocal ? false : cmd.IsPublic, // local books are always private
            IsLocal       = cmd.IsLocal,
            CreatedBy     = currentUser.UserName,
            BookGenres    = (cmd.GenreIds ?? Enumerable.Empty<Guid>())
                            .Select(gid => new BookGenre { GenreId = gid })
                            .ToList(),
        };

        await uow.Books.AddAsync(book, ct);

        // Local books are immediately owned by their creator — add to library automatically
        // so the user can open them from the library and the read-url gate passes.
        if (cmd.IsLocal && currentUser.UserId.HasValue)
        {
            await uow.UserBooks.AddAsync(new UserBook
            {
                UserId    = currentUser.UserId.Value,
                BookId    = book.Id,
                CreatedBy = currentUser.UserName,
            }, ct);
        }

        await uow.SaveChangesAsync(ct);

        // Publish the notification only when the book has a PDF already attached.
        // If FilePath is empty the PDF will be uploaded separately via POST /upload-pdf,
        // and that endpoint is responsible for publishing the event once the file lands.
        if (cmd.IsPublic && !cmd.IsLocal && !string.IsNullOrWhiteSpace(cmd.FilePath))
        {
            await publisher.PublishAsync(
                new { BookId = book.Id, BookTitle = book.Title, BookAuthor = book.Author },
                routingKey: "book.published",
                ct);
        }

        return Result<Guid>.Success(book.Id);
    }
}
