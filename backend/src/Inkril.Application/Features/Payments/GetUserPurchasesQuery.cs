using Inkril.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

public record UserPurchaseDto(
    Guid PurchaseId,
    Guid BookId,
    string BookTitle,
    long AmountCents,
    string Currency,
    DateTime? PaidAt);

public record GetUserPurchasesQuery(Guid UserId) : IRequest<IEnumerable<UserPurchaseDto>>;

public class GetUserPurchasesQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetUserPurchasesQuery, IEnumerable<UserPurchaseDto>>
{
    public async Task<IEnumerable<UserPurchaseDto>> Handle(
        GetUserPurchasesQuery q, CancellationToken ct)
    {
        return await uow.Purchases.Query()
            .Include(p => p.Book)
            .Where(p => p.UserId == q.UserId && p.Status == "succeeded")
            .OrderByDescending(p => p.PaidAt)
            .Select(p => new UserPurchaseDto(
                p.Id, p.BookId, p.Book.Title,
                p.AmountCents, p.Currency, p.PaidAt))
            .ToListAsync(ct);
    }
}
