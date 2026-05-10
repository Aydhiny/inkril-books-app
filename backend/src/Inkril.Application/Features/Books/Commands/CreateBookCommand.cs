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
    string FilePath,
    long FileSizeBytes,
    int TotalPages,
    DateTime PublishedDate,
    string? ISBN,
    string? Publisher,
    string? Language,
    bool IsPublic,
    IEnumerable<Guid> GenreIds
) : IRequest<Result<Guid>>;

public class CreateBookCommandValidator : AbstractValidator<CreateBookCommand>
{
    public CreateBookCommandValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Author).NotEmpty().MaximumLength(200);
        RuleFor(x => x.FilePath).NotEmpty();
        RuleFor(x => x.TotalPages).GreaterThanOrEqualTo(0);
        RuleFor(x => x.PublishedDate).LessThanOrEqualTo(DateTime.UtcNow);
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
            Title = cmd.Title,
            Author = cmd.Author,
            Description = cmd.Description,
            CoverImageUrl = cmd.CoverImageUrl,
            FilePath = cmd.FilePath,
            FileSizeBytes = cmd.FileSizeBytes,
            TotalPages = cmd.TotalPages,
            PublishedDate = cmd.PublishedDate,
            ISBN = cmd.ISBN,
            Publisher = cmd.Publisher,
            Language = cmd.Language ?? "en",
            IsPublic = cmd.IsPublic,
            CreatedBy = currentUser.UserName,
            BookGenres = cmd.GenreIds.Select(gid => new BookGenre { GenreId = gid }).ToList()
        };

        await uow.Books.AddAsync(book, ct);
        await uow.SaveChangesAsync(ct);

        // Notify all users via RabbitMQ → NotificationWorker will fan out to opted-in users
        if (cmd.IsPublic)
        {
            await publisher.PublishAsync(
                new { BookId = book.Id, BookTitle = book.Title, BookAuthor = book.Author },
                routingKey: "book.published",
                ct);
        }

        return Result<Guid>.Success(book.Id);
    }
}
