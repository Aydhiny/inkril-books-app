using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Books.Queries;

public record BookDto(
    Guid Id, string Title, string Author, string? Description,
    string? CoverImageUrl, long FileSizeBytes, int TotalPages,
    DateTime PublishedDate, bool IsPublic, double AverageRating,
    int RatingCount, IEnumerable<string> Genres,
    bool IsPremium, decimal? Price);

public record GetBooksQuery(
    string? SearchTerm,
    Guid? GenreId,
    DateTime? PublishedFrom,
    DateTime? PublishedTo,
    int PageNumber = 1,
    int PageSize = 20
) : IRequest<PagedList<BookDto>>;

public class GetBooksQueryHandler(IUnitOfWork uow) : IRequestHandler<GetBooksQuery, PagedList<BookDto>>
{
    private const int MaxPageSize = 100;

    public async Task<PagedList<BookDto>> Handle(GetBooksQuery q, CancellationToken ct)
    {
        var pageSize = Math.Min(q.PageSize, MaxPageSize);
        var query = uow.Books.Query()
            .Include(b => b.BookGenres).ThenInclude(bg => bg.Genre)
            .Where(b => !b.IsDeleted && b.IsActive && b.IsPublic);

        if (!string.IsNullOrWhiteSpace(q.SearchTerm))
            query = query.Where(b => b.Title.Contains(q.SearchTerm) || b.Author.Contains(q.SearchTerm));

        if (q.GenreId.HasValue)
            query = query.Where(b => b.BookGenres.Any(bg => bg.GenreId == q.GenreId));

        if (q.PublishedFrom.HasValue)
        {
            // Npgsql requires DateTimeKind.Utc for timestamptz columns.
            // ASP.NET model binding produces Kind=Unspecified when no timezone is in the query string.
            var utcFrom = DateTime.SpecifyKind(q.PublishedFrom.Value, DateTimeKind.Utc);
            query = query.Where(b => b.PublishedDate >= utcFrom);
        }

        if (q.PublishedTo.HasValue)
        {
            var utcTo = DateTime.SpecifyKind(q.PublishedTo.Value, DateTimeKind.Utc);
            query = query.Where(b => b.PublishedDate <= utcTo);
        }

        // Count on the raw entity query before projecting — EF Core cannot translate
        // CountAsync on an IQueryable<BookDto> that contains a nested IEnumerable<string>.
        var count = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(b => b.CreatedAt)
            .Skip((q.PageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(b => new BookDto(
                b.Id, b.Title, b.Author, b.Description, b.CoverImageUrl,
                b.FileSizeBytes, b.TotalPages, b.PublishedDate, b.IsPublic,
                b.AverageRating, b.RatingCount,
                b.BookGenres.Select(bg => bg.Genre.Name),
                b.IsPremium, b.Price))
            .ToListAsync(ct);

        return new PagedList<BookDto>(items, count, q.PageNumber, pageSize);
    }
}
