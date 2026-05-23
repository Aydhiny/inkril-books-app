using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Payments;

public record CreatePaymentIntentCommand(Guid BookId, Guid UserId) : IRequest<Result<PaymentIntentDto>>;

public record PaymentIntentDto(string ClientSecret, string PaymentIntentId, long AmountCents, string Currency);

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
            return Result<PaymentIntentDto>.Failure("Book not found.");

        if (!book.IsPremium || book.Price is null or <= 0)
            return Result<PaymentIntentDto>.Failure("This book is not available for purchase.");

        // Prevent duplicate purchases
        var alreadyPurchased = await uow.Purchases.AnyAsync(
            p => p.UserId == cmd.UserId && p.BookId == cmd.BookId && p.Status == "succeeded", ct);

        if (alreadyPurchased)
            return Result<PaymentIntentDto>.Failure("You have already purchased this book.");

        // Convert price to cents (Stripe works in smallest currency unit)
        var amountCents = (long)Math.Round(book.Price.Value * 100);
        var description = $"Inkril — {book.Title} by {book.Author}";

        var (clientSecret, paymentIntentId) =
            await paymentService.CreatePaymentIntentAsync(amountCents, "usd", description, ct);

        // Create a pending Purchase record immediately so the PaymentIntent ID is tracked.
        // Status changes to "succeeded" when ConfirmPurchaseCommand runs after client confirms.
        await uow.Purchases.AddAsync(new Domain.Entities.Purchase
        {
            UserId              = cmd.UserId,
            BookId              = cmd.BookId,
            StripePaymentIntentId = paymentIntentId,
            AmountCents         = amountCents,
            Currency            = "usd",
            Status              = "pending",
            CreatedBy           = cmd.UserId.ToString()
        }, ct);

        await uow.SaveChangesAsync(ct);

        return Result<PaymentIntentDto>.Success(
            new PaymentIntentDto(clientSecret, paymentIntentId, amountCents, "usd"));
    }
}
