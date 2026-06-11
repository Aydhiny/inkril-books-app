using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

public record CreatePaymentIntentCommand(Guid BookId, Guid UserId) : IRequest<Result<PaymentIntentDto>>;

/// <summary>
/// Returned to the mobile client so it can initialise the Stripe Payment Sheet.
/// <see cref="StripeCustomerId"/> and <see cref="EphemeralKeySecret"/> are included
/// so the sheet can show the user's saved cards as a default payment option.
/// </summary>
public record PaymentIntentDto(
    string ClientSecret,
    string PaymentIntentId,
    long   AmountCents,
    string Currency,
    string StripeCustomerId,
    string EphemeralKeySecret);

public class CreatePaymentIntentCommandValidator : AbstractValidator<CreatePaymentIntentCommand>
{
    public CreatePaymentIntentCommandValidator()
    {
        RuleFor(x => x.BookId).NotEmpty();
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public class CreatePaymentIntentCommandHandler(IUnitOfWork uow, IPaymentService paymentService)
    : IRequestHandler<CreatePaymentIntentCommand, Result<PaymentIntentDto>>
{
    public async Task<Result<PaymentIntentDto>> Handle(
        CreatePaymentIntentCommand cmd, CancellationToken ct)
    {
        var book = await uow.Books.Query()
            .FirstOrDefaultAsync(b => b.Id == cmd.BookId && !b.IsDeleted, ct);

        if (book is null)
            return Result<PaymentIntentDto>.NotFound("Book not found.");

        if (!book.IsPremium || book.Price is null or <= 0)
            return Result<PaymentIntentDto>.Failure("This book is not available for purchase.");

        var alreadyPurchased = await uow.Purchases.AnyAsync(
            p => p.UserId == cmd.UserId && p.BookId == cmd.BookId
              && p.Status == PurchaseStatus.Succeeded, ct);

        if (alreadyPurchased)
            return Result<PaymentIntentDto>.Conflict("You have already purchased this book.");

        var amountCents = (long)Math.Round(book.Price.Value * 100);

        // If a Pending purchase already exists, resume it rather than creating a duplicate
        // PaymentIntent — Stripe would otherwise accumulate uncancelled intents for the same charge.
        var existingPending = await uow.Purchases.FirstOrDefaultAsync(
            p => p.UserId == cmd.UserId && p.BookId == cmd.BookId
              && p.Status == PurchaseStatus.Pending, ct);

        var stripeCustomerId = await paymentService.EnsureCustomerAsync(cmd.UserId, ct);
        var ephemeralKey     = await paymentService.CreateEphemeralKeyAsync(stripeCustomerId, ct);

        if (existingPending is not null)
        {
            var (existingSecret, existingPiId) =
                await paymentService.RetrievePaymentIntentAsync(
                    existingPending.StripePaymentIntentId, ct);
            return Result<PaymentIntentDto>.Success(
                new PaymentIntentDto(existingSecret, existingPiId,
                    existingPending.AmountCents, "usd", stripeCustomerId, ephemeralKey));
        }

        var description = $"Inkril — {book.Title} by {book.Author}";
        var (clientSecret, paymentIntentId) =
            await paymentService.CreatePaymentIntentAsync(
                amountCents, "usd", description, stripeCustomerId, ct);

        await uow.Purchases.AddAsync(new Domain.Entities.Purchase
        {
            UserId                = cmd.UserId,
            BookId                = cmd.BookId,
            StripePaymentIntentId = paymentIntentId,
            AmountCents           = amountCents,
            Currency              = "usd",
            CreatedBy             = cmd.UserId.ToString()
        }, ct);

        await uow.SaveChangesAsync(ct);

        return Result<PaymentIntentDto>.Success(
            new PaymentIntentDto(clientSecret, paymentIntentId, amountCents, "usd",
                stripeCustomerId, ephemeralKey));
    }
}
