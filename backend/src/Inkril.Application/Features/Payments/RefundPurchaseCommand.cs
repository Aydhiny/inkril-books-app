using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

/// <summary>
/// Issues a full refund for a succeeded purchase and transitions it to
/// <see cref="PurchaseStatus.Refunded"/> via the entity state machine.
/// </summary>
public record RefundPurchaseCommand(string PaymentIntentId, Guid UserId) : IRequest<Result>;

public class RefundPurchaseCommandValidator : AbstractValidator<RefundPurchaseCommand>
{
    public RefundPurchaseCommandValidator()
    {
        RuleFor(x => x.PaymentIntentId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public class RefundPurchaseCommandHandler(IUnitOfWork uow, IPaymentService paymentService)
    : IRequestHandler<RefundPurchaseCommand, Result>
{
    public async Task<Result> Handle(RefundPurchaseCommand cmd, CancellationToken ct)
    {
        var purchase = await uow.Purchases.Query()
            .FirstOrDefaultAsync(
                p => p.StripePaymentIntentId == cmd.PaymentIntentId
                  && p.UserId == cmd.UserId, ct);

        if (purchase is null)
            return Result.Failure("Purchase not found.");

        // Guard: only Succeeded or PartiallyRefunded can be fully refunded
        if (purchase.Status != PurchaseStatus.Succeeded
         && purchase.Status != PurchaseStatus.PartiallyRefunded)
            return Result.Failure(
                $"Cannot refund a purchase in status '{purchase.Status}'.");

        // Issue full refund on Stripe (remaining amount = original - already refunded)
        var remaining = purchase.AmountCents - purchase.RefundedAmountCents;
        var refundId  = await paymentService.RefundPaymentAsync(
            cmd.PaymentIntentId, remaining, ct);

        purchase.RefundedAmountCents = purchase.AmountCents; // fully refunded
        purchase.StripeRefundId      = refundId;
        purchase.UpdatedAt           = DateTime.UtcNow;

        // State machine: Succeeded|PartiallyRefunded → Refunded
        purchase.Transition(PurchaseStatus.Refunded);

        uow.Purchases.Update(purchase);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
