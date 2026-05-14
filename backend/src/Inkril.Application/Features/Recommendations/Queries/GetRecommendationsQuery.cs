using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Books.Queries;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

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

public class GetRecommendationsQueryHandler(
    IUnitOfWork uow,
    IRecommendationService recommendationService,
    IMemoryCache cache)
    : IRequestHandler<GetRecommendationsQuery, IEnumerable<RecommendedBookDto>>
{
    // Recommendations are expensive: the service scores every unread book by
    // genre overlap and collaborative signals. A user's taste profile rarely
    // changes minute-to-minute, so a 5-minute per-user cache is an acceptable
    // trade-off between freshness and CPU/DB cost.
    private static string CacheKey(Guid userId, int count) => $"recs:{userId}:{count}";

    public async Task<IEnumerable<RecommendedBookDto>> Handle(GetRecommendationsQuery q, CancellationToken ct)
    {
        return await cache.GetOrCreateAsync(
            CacheKey(q.UserId, q.Count),
            async ce =>
            {
                ce.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);

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

                // Preserve recommendation order and attach the reason string
                return (IEnumerable<RecommendedBookDto>)recommendedIds
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
            }) ?? [];
    }
}
