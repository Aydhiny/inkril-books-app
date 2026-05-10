using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Bookmarks.Queries;

public record RandomHighlightDto(string HighlightedText, string BookTitle, int PageNumber);

public record GetRandomHighlightQuery(Guid UserId) : IRequest<Result<RandomHighlightDto?>>;

public class GetRandomHighlightQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetRandomHighlightQuery, Result<RandomHighlightDto?>>
{
    public async Task<Result<RandomHighlightDto?>> Handle(GetRandomHighlightQuery q, CancellationToken ct)
    {
        // Count highlights so we can pick a random one without loading all of them
        var count = await uow.Bookmarks.Query()
            .Where(b => b.UserId == q.UserId && !b.IsDeleted && b.HighlightedText != null)
            .CountAsync(ct);

        if (count == 0)
            return Result<RandomHighlightDto?>.Success(null);

        // Deterministic-per-day randomness: day-of-year mod count
        var dayOfYear = DateTime.UtcNow.DayOfYear;
        var skip      = dayOfYear % count;

        var highlight = await uow.Bookmarks.Query()
            .Where(b => b.UserId == q.UserId && !b.IsDeleted && b.HighlightedText != null)
            .OrderBy(b => b.CreatedAt)
            .Skip(skip)
            .Select(b => new { b.HighlightedText, b.Book.Title, b.PageNumber })
            .FirstOrDefaultAsync(ct);

        if (highlight is null)
            return Result<RandomHighlightDto?>.Success(null);

        return Result<RandomHighlightDto?>.Success(
            new RandomHighlightDto(highlight.HighlightedText!, highlight.Title, highlight.PageNumber));
    }
}
