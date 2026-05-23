using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
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
        // Retrieve the pending Purchase record created by CreatePaymentIntentCommand
        var purchase = await uow.Purchases.Query()
            .FirstOrDefaultAsync(
                p => p.StripePaymentIntentId == cmd.PaymentIntentId
                  && p.UserId == cmd.UserId, ct);

        if (purchase is null)
            return Result.Failure("Purchase record not found.");

        if (purchase.Status == "succeeded")
            return Result.Success(); // Idempotent — already confirmed

        // Verify with Stripe that payment actually succeeded (prevents fake confirmations)
        var succeeded = await paymentService.IsPaymentSucceededAsync(cmd.PaymentIntentId, ct);
        if (!succeeded)
            return Result.Failure("Payment has not been completed. Please try again.");

        purchase.Status = "succeeded";
        purchase.PaidAt = DateTime.UtcNow;
        purchase.UpdatedAt = DateTime.UtcNow;
        uow.Purchases.Update(purchase);

        // Add the book to the user's library so the existing ownership-based read-url
        // gate (GetBookReadUrlQuery → UserBooks check) grants access automatically.
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
