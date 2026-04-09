using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Books.Queries;

public record BookDetailDto(
    Guid Id, string Title, string Author, string? Description,
    string? CoverImageUrl, string FilePath, long FileSizeBytes,
    int TotalPages, DateTime PublishedDate, string? ISBN,
    string? Publisher, string? Language, double AverageRating,
    int RatingCount, IEnumerable<string> Genres);

public record GetBookByIdQuery(Guid BookId, Guid? RequestingUserId) : IRequest<Result<BookDetailDto>>;

public class GetBookByIdQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetBookByIdQuery, Result<BookDetailDto>>
{
    public async Task<Result<BookDetailDto>> Handle(GetBookByIdQuery q, CancellationToken ct)
    {
        var book = await uow.Books.Query()
            .Include(b => b.BookGenres).ThenInclude(bg => bg.Genre)
            .FirstOrDefaultAsync(b => b.Id == q.BookId && !b.IsDeleted, ct);

        if (book is null)
            return Result<BookDetailDto>.Failure("Book not found.");

        return Result<BookDetailDto>.Success(new BookDetailDto(
            book.Id, book.Title, book.Author, book.Description,
            book.CoverImageUrl, book.FilePath, book.FileSizeBytes,
            book.TotalPages, book.PublishedDate, book.ISBN,
            book.Publisher, book.Language, book.AverageRating,
            book.RatingCount,
            book.BookGenres.Select(bg => bg.Genre.Name)));
    }
}
