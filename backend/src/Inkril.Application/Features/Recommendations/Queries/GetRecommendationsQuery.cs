using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Books.Queries;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Recommendations.Queries;

/// <summary>
/// A BookDto extended with the recommendation reason (§2.4 — explainable recommendations).
/// </summary>
public record RecommendedBookDto(
    Guid Id,
    string Title,
    string Author,
    string? Description,
    string? CoverImageUrl,
    long? FileSizeBytes,
    int TotalPages,
    DateTime? PublishedDate,
    bool IsPublic,
    double AverageRating,
    int RatingCount,
    IEnumerable<string> Genres,
    string Reason);

public record GetRecommendationsQuery(Guid UserId, int Count = 10) : IRequest<IEnumerable<RecommendedBookDto>>;

public class GetRecommendationsQueryHandler(IUnitOfWork uow, IRecommendationService recommendationService)
    : IRequestHandler<GetRecommendationsQuery, IEnumerable<RecommendedBookDto>>
{
    public async Task<IEnumerable<RecommendedBookDto>> Handle(GetRecommendationsQuery q, CancellationToken ct)
    {
        var recommendations = await recommendationService.GetRecommendedBooksAsync(q.UserId, q.Count, ct);
        var reasonByBookId = recommendations.ToDictionary(r => r.BookId, r => r.Reason);
        var recommendedIds = reasonByBookId.Keys.ToList();

        var books = await uow.Books.Query()
            .Include(b => b.BookGenres).ThenInclude(bg => bg.Genre)
            .Where(b => recommendedIds.Contains(b.Id) && !b.IsDeleted && b.IsPublic)
            .Select(b => new
            {
                b.Id, b.Title, b.Author, b.Description, b.CoverImageUrl,
                b.FileSizeBytes, b.TotalPages, b.PublishedDate, b.IsPublic,
                b.AverageRating, b.RatingCount,
                Genres = b.BookGenres.Select(bg => bg.Genre.Name)
            })
            .ToListAsync(ct);

        // Preserve the recommendation order and attach the reason
        return recommendedIds
            .Where(id => books.Any(b => b.Id == id))
            .Select(id =>
            {
                var b = books.First(x => x.Id == id);
                return new RecommendedBookDto(
                    b.Id, b.Title, b.Author, b.Description, b.CoverImageUrl,
                    b.FileSizeBytes, b.TotalPages, b.PublishedDate, b.IsPublic,
                    b.AverageRating, b.RatingCount, b.Genres,
                    reasonByBookId[id]);
            })
            .ToList();
    }
}
