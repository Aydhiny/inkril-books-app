using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Payments;

/// <summary>
/// Detaches a saved PaymentMethod from the user's Stripe Customer.
/// Ownership is verified by confirming the PM's customer matches the caller.
/// </summary>
public record RemovePaymentMethodCommand(Guid UserId, string PaymentMethodId)
    : IRequest<Result>;

public class RemovePaymentMethodCommandValidator : AbstractValidator<RemovePaymentMethodCommand>
{
    public RemovePaymentMethodCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentMethodId).NotEmpty();
    }
}

public class RemovePaymentMethodCommandHandler(IPaymentService paymentService)
    : IRequestHandler<RemovePaymentMethodCommand, Result>
{
    public async Task<Result> Handle(
        RemovePaymentMethodCommand cmd, CancellationToken ct)
    {
        // Verify the PM actually belongs to this user's customer before detaching.
        // This prevents one user from deleting another user's saved card.
        var customerId = await paymentService.EnsureCustomerAsync(cmd.UserId, ct);
        var methods    = await paymentService.ListPaymentMethodsAsync(customerId, ct);

        var owned = methods.Any(m => m.Id == cmd.PaymentMethodId);
        if (!owned)
            return Result.Failure("Payment method not found.");

        await paymentService.DetachPaymentMethodAsync(cmd.PaymentMethodId, ct);
        return Result.Success();
    }
}
