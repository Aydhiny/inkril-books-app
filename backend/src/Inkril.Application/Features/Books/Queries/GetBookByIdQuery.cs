using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Books.Queries;

/// <summary>
/// Public book detail DTO — FilePath is intentionally excluded.
/// The storage path is only returned through GET /api/books/{id}/read-url
/// after the server verifies the requesting user owns the book (UserBooks).
/// </summary>
public record BookDetailDto(
    Guid Id, string Title, string Author, string? Description,
    string? CoverImageUrl, long FileSizeBytes,
    int TotalPages, DateTime PublishedDate, string? ISBN,
    string? Publisher, string? Language, double AverageRating,
    int RatingCount, IEnumerable<string> Genres,
    bool IsPremium, decimal? Price, bool IsPurchasedByUser,
    bool IsLocal,
    bool IsPublic, bool IsInLibrary,
    double? ReadingProgressPercent, DateTime? LastReadAt, int? LastReadPage);

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
            return Result<BookDetailDto>.NotFound("Book not found.");

        var isPurchased = q.RequestingUserId.HasValue && await uow.Purchases.AnyAsync(
            p => p.UserId == q.RequestingUserId.Value
              && p.BookId == q.BookId
              && p.Status == PurchaseStatus.Succeeded, ct);

        var userBook = q.RequestingUserId.HasValue
            ? await uow.UserBooks.FirstOrDefaultAsync(
                ub => ub.UserId == q.RequestingUserId.Value
                   && ub.BookId == q.BookId
                   && !ub.IsDeleted, ct)
            : null;

        return Result<BookDetailDto>.Success(new BookDetailDto(
            book.Id, book.Title, book.Author, book.Description,
            book.CoverImageUrl, book.FileSizeBytes,
            book.TotalPages, book.PublishedDate, book.ISBN,
            book.Publisher, book.Language, book.AverageRating,
            book.RatingCount,
            book.BookGenres.Where(bg => bg.Genre is not null).Select(bg => bg.Genre.Name),
            book.IsPremium, book.Price, isPurchased,
            book.IsLocal,
            book.IsPublic,
            IsInLibrary: userBook is not null,
            ReadingProgressPercent: userBook?.ReadingProgressPercent,
            LastReadAt: userBook?.LastReadAt,
            LastReadPage: userBook?.LastReadPageNumber));
    }
}
