using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

public record ConfirmPurchaseCommand(string PaymentIntentId, Guid UserId) : IRequest<Result>;

public class ConfirmPurchaseCommandValidator : AbstractValidator<ConfirmPurchaseCommand>
{
    public ConfirmPurchaseCommandValidator()
    {
        RuleFor(x => x.PaymentIntentId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public class ConfirmPurchaseCommandHandler(IUnitOfWork uow, IPaymentService paymentService)
    : IRequestHandler<ConfirmPurchaseCommand, Result>
{
    public async Task<Result> Handle(ConfirmPurchaseCommand cmd, CancellationToken ct)
    {
        var purchase = await uow.Purchases.Query()
            .FirstOrDefaultAsync(
                p => p.StripePaymentIntentId == cmd.PaymentIntentId
                  && p.UserId == cmd.UserId, ct);

        if (purchase is null)
            return Result.Failure("Purchase record not found.");

        // Idempotent — if already confirmed don't re-verify with Stripe
        if (purchase.Status == PurchaseStatus.Succeeded)
            return Result.Success();

        var succeeded = await paymentService.IsPaymentSucceededAsync(cmd.PaymentIntentId, ct);
        if (!succeeded)
            return Result.Failure("Payment has not been completed. Please try again.");

        // State machine enforces Pending → Succeeded
        purchase.Transition(PurchaseStatus.Succeeded);
        purchase.PaidAt    = DateTime.UtcNow;
        purchase.UpdatedAt = DateTime.UtcNow;
        uow.Purchases.Update(purchase);

        // Add book to user's library so the existing read-url gate grants access
        var alreadyInLibrary = await uow.UserBooks.AnyAsync(
            ub => ub.UserId == cmd.UserId && ub.BookId == purchase.BookId, ct);

        if (!alreadyInLibrary)
        {
            await uow.UserBooks.AddAsync(new Domain.Entities.UserBook
            {
                UserId    = cmd.UserId,
                BookId    = purchase.BookId,
                AddedAt   = DateTime.UtcNow,
                CreatedBy = cmd.UserId.ToString()
            }, ct);
        }

        await uow.SaveChangesAsync(ct);
        return Result.Success();
    }
}
