using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

/// <summary>
/// Confirms a purchase as succeeded and adds the book to the user's library.
///
/// <para>
/// Called from two paths:
/// <list type="bullet">
///   <item>
///     <b>Webhook (preferred)</b> — <c>POST /api/webhooks/stripe</c> on
///     <c>payment_intent.succeeded</c>. <paramref name="UserId"/> is <c>null</c>;
///     the handler looks up the purchase by PaymentIntentId alone.
///   </item>
///   <item>
///     <b>Client fallback</b> — <c>POST /api/payments/confirm</c> called by the
///     mobile app after the Payment Sheet reports success. <paramref name="UserId"/> is
///     set so the query is scoped to the requesting user (ownership check). The handler
///     still re-verifies the PaymentIntent status with Stripe before confirming.
///   </item>
/// </list>
/// </para>
/// </summary>
public record ConfirmPurchaseCommand(string PaymentIntentId, Guid? UserId) : IRequest<Result>;

public class ConfirmPurchaseCommandValidator : AbstractValidator<ConfirmPurchaseCommand>
{
    public ConfirmPurchaseCommandValidator()
    {
        RuleFor(x => x.PaymentIntentId).NotEmpty().MaximumLength(100);
        // UserId is nullable — omitted when called from the Stripe webhook
    }
}

public class ConfirmPurchaseCommandHandler(IUnitOfWork uow, IPaymentService paymentService)
    : IRequestHandler<ConfirmPurchaseCommand, Result>
{
    public async Task<Result> Handle(ConfirmPurchaseCommand cmd, CancellationToken ct)
    {
        // When called from the webhook, UserId is null — look up by PaymentIntentId only.
        // When called from the mobile client, scope to the requesting user as an ownership check.
        var purchase = cmd.UserId.HasValue
            ? await uow.Purchases.Query()
                .FirstOrDefaultAsync(
                    p => p.StripePaymentIntentId == cmd.PaymentIntentId
                      && p.UserId == cmd.UserId.Value, ct)
            : await uow.Purchases.Query()
                .FirstOrDefaultAsync(
                    p => p.StripePaymentIntentId == cmd.PaymentIntentId, ct);

        if (purchase is null)
            return Result.Failure("Purchase record not found.");

        // Idempotent — webhook may fire more than once; client may also call confirm
        // after the webhook has already confirmed. Both paths are safe.
        if (purchase.Status == PurchaseStatus.Succeeded)
            return Result.Success();

        // When called from the client, verify with Stripe before trusting the request.
        // When called from the webhook the event itself is the authoritative signal,
        // but we verify anyway so both paths share the same safety guarantee.
        var succeeded = await paymentService.IsPaymentSucceededAsync(cmd.PaymentIntentId, ct);
        if (!succeeded)
            return Result.Failure("Payment has not been completed. Please try again.");

        // State machine enforces Pending → Succeeded
        purchase.Transition(PurchaseStatus.Succeeded);
        purchase.PaidAt    = DateTime.UtcNow;
        purchase.UpdatedAt = DateTime.UtcNow;
        uow.Purchases.Update(purchase);

        // Add book to user's library so the read-url gate grants access
        var userId = purchase.UserId;
        var alreadyInLibrary = await uow.UserBooks.AnyAsync(
            ub => ub.UserId == userId && ub.BookId == purchase.BookId, ct);

        if (!alreadyInLibrary)
        {
            await uow.UserBooks.AddAsync(new Domain.Entities.UserBook
            {
                UserId    = userId,
                BookId    = purchase.BookId,
                AddedAt   = DateTime.UtcNow,
                CreatedBy = userId.ToString()
            }, ct);
        }

        await uow.SaveChangesAsync(ct);
        return Result.Success();
    }
}
