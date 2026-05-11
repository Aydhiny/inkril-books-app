using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Bookmarks.Queries;

public record BookmarkDto(
    Guid Id,
    int PageNumber,
    string? HighlightedText,
    string? Note,
    string? Color,
    DateTime CreatedAt);

public record GetBookBookmarksQuery(
    Guid UserId,
    Guid BookId,
    int PageNumber = 1,
    int PageSize = 50) : IRequest<PagedList<BookmarkDto>>;

public class GetBookBookmarksQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetBookBookmarksQuery, PagedList<BookmarkDto>>
{
    private const int MaxPageSize = 100;

    public async Task<PagedList<BookmarkDto>> Handle(GetBookBookmarksQuery q, CancellationToken ct)
    {
        var pageSize = Math.Min(q.PageSize, MaxPageSize);

        var allBookmarks = await uow.Bookmarks.FindAsync(
            b => b.UserId == q.UserId && b.BookId == q.BookId, ct);

        var ordered = allBookmarks
            .OrderBy(b => b.PageNumber)
            .Select(b => new BookmarkDto(b.Id, b.PageNumber, b.HighlightedText, b.Note, b.Color, b.CreatedAt))
            .ToList();

        var paged = ordered
            .Skip((q.PageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToList();

        return new PagedList<BookmarkDto>(paged, ordered.Count, q.PageNumber, pageSize);
    }
}
