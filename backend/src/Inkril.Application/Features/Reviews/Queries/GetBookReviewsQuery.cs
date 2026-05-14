using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Reviews.Queries;

public record ReviewDto(
    Guid Id,
    Guid UserId,
    string UserName,
    int Rating,
    string? Comment,
    DateTime CreatedAt,
    bool IsEdited);

public record GetBookReviewsQuery(Guid BookId, int PageNumber = 1, int PageSize = 10)
    : IRequest<PagedList<ReviewDto>>;

public class GetBookReviewsQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetBookReviewsQuery, PagedList<ReviewDto>>
{
    private const int MaxPageSize = 50;

    public async Task<PagedList<ReviewDto>> Handle(GetBookReviewsQuery q, CancellationToken ct)
    {
        var pageSize = Math.Min(q.PageSize, MaxPageSize);
        var query = uow.Reviews.Query()
            .Include(r => r.User)
            .Where(r => r.BookId == q.BookId)
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new ReviewDto(
                r.Id, r.UserId, r.User.UserName!, r.Rating,
                r.Comment, r.CreatedAt, r.IsEdited));

        return await PagedList<ReviewDto>.CreateAsync(query, q.PageNumber, pageSize, ct);
    }
}
