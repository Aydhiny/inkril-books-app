using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

/// <summary>
/// Marks a pending purchase as Failed when Stripe fires payment_intent.payment_failed.
/// Called exclusively from the Stripe webhook handler — not exposed as an API endpoint.
/// </summary>
public record FailPurchaseCommand(string PaymentIntentId) : IRequest<Result>;

public class FailPurchaseCommandHandler(IUnitOfWork uow)
    : IRequestHandler<FailPurchaseCommand, Result>
{
    public async Task<Result> Handle(FailPurchaseCommand cmd, CancellationToken ct)
    {
        var purchase = await uow.Purchases.Query()
            .FirstOrDefaultAsync(p => p.StripePaymentIntentId == cmd.PaymentIntentId, ct);

        if (purchase is null)
            return Result.Failure("Purchase record not found.");

        // Idempotent — already in a terminal state (Failed/Refunded), nothing to do
        if (purchase.Status is PurchaseStatus.Failed or PurchaseStatus.Refunded)
            return Result.Success();

        purchase.Transition(PurchaseStatus.Failed);
        purchase.UpdatedAt = DateTime.UtcNow;
        uow.Purchases.Update(purchase);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
