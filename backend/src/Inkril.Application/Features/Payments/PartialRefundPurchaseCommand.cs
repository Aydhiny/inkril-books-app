using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

/// <summary>
/// Issues a partial refund for a succeeded (or already partially-refunded) purchase.
///
/// The state machine allows:
///   Succeeded         → PartiallyRefunded
///   PartiallyRefunded → PartiallyRefunded  (additional partial refund)
///   PartiallyRefunded → Refunded           (if this refund covers the remainder)
///
/// The handler automatically picks the correct target state based on the
/// cumulative refunded amount vs. the original charge.
/// </summary>
public record PartialRefundPurchaseCommand(
    string PaymentIntentId,
    long   RefundAmountCents,
    Guid   UserId) : IRequest<Result<PartialRefundResultDto>>;

public record PartialRefundResultDto(
    PurchaseStatus NewStatus,
    long           TotalRefundedCents,
    long           RemainingCents);

public class PartialRefundPurchaseCommandValidator
    : AbstractValidator<PartialRefundPurchaseCommand>
{
    public PartialRefundPurchaseCommandValidator()
    {
        RuleFor(x => x.PaymentIntentId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.RefundAmountCents)
            .GreaterThan(0)
            .WithMessage("Refund amount must be greater than zero.");
    }
}

public class PartialRefundPurchaseCommandHandler(IUnitOfWork uow, IPaymentService paymentService)
    : IRequestHandler<PartialRefundPurchaseCommand, Result<PartialRefundResultDto>>
{
    public async Task<Result<PartialRefundResultDto>> Handle(
        PartialRefundPurchaseCommand cmd, CancellationToken ct)
    {
        var purchase = await uow.Purchases.Query()
            .FirstOrDefaultAsync(
                p => p.StripePaymentIntentId == cmd.PaymentIntentId
                  && p.UserId == cmd.UserId, ct);

        if (purchase is null)
            return Result<PartialRefundResultDto>.Failure("Purchase not found.");

        if (purchase.Status != PurchaseStatus.Succeeded
         && purchase.Status != PurchaseStatus.PartiallyRefunded)
            return Result<PartialRefundResultDto>.Failure(
                $"Cannot partially refund a purchase in status '{purchase.Status}'.");

        var remaining = purchase.AmountCents - purchase.RefundedAmountCents;

        if (cmd.RefundAmountCents > remaining)
            return Result<PartialRefundResultDto>.Failure(
                $"Refund amount ({cmd.RefundAmountCents}¢) exceeds the remaining " +
                $"refundable balance ({remaining}¢).");

        // Issue the partial refund on Stripe
        var refundId = await paymentService.RefundPaymentAsync(
            cmd.PaymentIntentId, cmd.RefundAmountCents, ct);

        purchase.RefundedAmountCents += cmd.RefundAmountCents;
        purchase.StripeRefundId       = refundId;
        purchase.UpdatedAt            = DateTime.UtcNow;

        // Determine the correct next state:
        // If this refund covers the full remaining balance → Refunded (terminal)
        // Otherwise → PartiallyRefunded (more refunds may follow)
        var newStatus = purchase.RefundedAmountCents >= purchase.AmountCents
            ? PurchaseStatus.Refunded
            : PurchaseStatus.PartiallyRefunded;

        purchase.Transition(newStatus);
        uow.Purchases.Update(purchase);
        await uow.SaveChangesAsync(ct);

        return Result<PartialRefundResultDto>.Success(new PartialRefundResultDto(
            newStatus,
            purchase.RefundedAmountCents,
            purchase.AmountCents - purchase.RefundedAmountCents));
    }
}
