using Inkril.Application.Common.Interfaces;
using MediatR;

namespace Inkril.Application.Features.Bookmarks.Queries;

public record BookmarkDto(
    Guid Id,
    int PageNumber,
    string? HighlightedText,
    string? Note,
    string? Color,
    DateTime CreatedAt);

public record GetBookBookmarksQuery(Guid UserId, Guid BookId) : IRequest<IEnumerable<BookmarkDto>>;

public class GetBookBookmarksQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetBookBookmarksQuery, IEnumerable<BookmarkDto>>
{
    public async Task<IEnumerable<BookmarkDto>> Handle(GetBookBookmarksQuery q, CancellationToken ct)
    {
        var bookmarks = await uow.Bookmarks.FindAsync(
            b => b.UserId == q.UserId && b.BookId == q.BookId, ct);

        return bookmarks
            .OrderBy(b => b.PageNumber)
            .Select(b => new BookmarkDto(b.Id, b.PageNumber, b.HighlightedText, b.Note, b.Color, b.CreatedAt));
    }
}
