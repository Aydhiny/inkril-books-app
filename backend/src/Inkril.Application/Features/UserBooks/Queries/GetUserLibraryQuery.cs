using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.UserBooks.Queries;

public record UserLibraryBookDto(
    Guid UserBookId,
    Guid BookId,
    string Title,
    string Author,
    string? CoverImageUrl,
    double ReadingProgressPercent,
    DateTime? LastReadAt,
    bool IsCompleted);

public record GetUserLibraryQuery(Guid UserId, int PageNumber = 1, int PageSize = 20)
    : IRequest<PagedList<UserLibraryBookDto>>;

public class GetUserLibraryQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetUserLibraryQuery, PagedList<UserLibraryBookDto>>
{
    public async Task<PagedList<UserLibraryBookDto>> Handle(GetUserLibraryQuery q, CancellationToken ct)
    {
        var query = uow.UserBooks.Query()
            .Include(ub => ub.Book)
            .Where(ub => ub.UserId == q.UserId && !ub.Book.IsDeleted)
            .OrderByDescending(ub => ub.LastReadAt ?? ub.AddedAt)
            .Select(ub => new UserLibraryBookDto(
                ub.Id,
                ub.BookId,
                ub.Book.Title,
                ub.Book.Author,
                ub.Book.CoverImageUrl,
                ub.ReadingProgressPercent,
                ub.LastReadAt,
                ub.IsCompleted));

        return await PagedList<UserLibraryBookDto>.CreateAsync(query, q.PageNumber, q.PageSize, ct);
    }
}
