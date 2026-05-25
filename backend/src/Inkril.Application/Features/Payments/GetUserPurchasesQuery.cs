using Inkril.Application.Common.Interfaces;
using Inkril.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

public record UserPurchaseDto(
    Guid      PurchaseId,
    Guid      BookId,
    string    BookTitle,
    long      AmountCents,
    long      RefundedAmountCents,
    string    Currency,
    string    Status,
    DateTime? PaidAt);

public record GetUserPurchasesQuery(Guid UserId) : IRequest<IEnumerable<UserPurchaseDto>>;

public class GetUserPurchasesQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetUserPurchasesQuery, IEnumerable<UserPurchaseDto>>
{
    public async Task<IEnumerable<UserPurchaseDto>> Handle(
        GetUserPurchasesQuery q, CancellationToken ct)
    {
        // Return all non-pending/non-failed purchases so refunded entries are visible
        return await uow.Purchases.Query()
            .Include(p => p.Book)
            .Where(p => p.UserId == q.UserId
                     && p.Status != PurchaseStatus.Pending
                     && p.Status != PurchaseStatus.Failed)
            .OrderByDescending(p => p.PaidAt)
            .Select(p => new UserPurchaseDto(
                p.Id,
                p.BookId,
                p.Book.Title,
                p.AmountCents,
                p.RefundedAmountCents,
                p.Currency,
                p.Status.ToString(),
                p.PaidAt))
            .ToListAsync(ct);
    }
}
