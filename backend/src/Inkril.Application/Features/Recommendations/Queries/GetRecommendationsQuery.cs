using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Books.Queries;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Recommendations.Queries;

public record GetRecommendationsQuery(Guid UserId, int Count = 10) : IRequest<IEnumerable<BookDto>>;

public class GetRecommendationsQueryHandler(IUnitOfWork uow, IRecommendationService recommendationService)
    : IRequestHandler<GetRecommendationsQuery, IEnumerable<BookDto>>
{
    public async Task<IEnumerable<BookDto>> Handle(GetRecommendationsQuery q, CancellationToken ct)
    {
        var recommendedIds = await recommendationService.GetRecommendedBookIdsAsync(q.UserId, q.Count, ct);

        return await uow.Books.Query()
            .Include(b => b.BookGenres).ThenInclude(bg => bg.Genre)
            .Where(b => recommendedIds.Contains(b.Id) && !b.IsDeleted && b.IsPublic)
            .Select(b => new BookDto(
                b.Id, b.Title, b.Author, b.Description, b.CoverImageUrl,
                b.FileSizeBytes, b.TotalPages, b.PublishedDate, b.IsPublic,
                b.AverageRating, b.RatingCount,
                b.BookGenres.Select(bg => bg.Genre.Name)))
            .ToListAsync(ct);
    }
}
