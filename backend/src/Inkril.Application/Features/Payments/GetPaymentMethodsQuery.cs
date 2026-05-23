using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Payments;

/// <summary>
/// Returns all saved card-type PaymentMethods for the current user.
/// If the user has no Stripe Customer yet, returns an empty list rather than erroring.
/// </summary>
public record GetPaymentMethodsQuery(Guid UserId) : IRequest<Result<IReadOnlyList<SavedCardDto>>>;

public class GetPaymentMethodsQueryHandler(IPaymentService paymentService)
    : IRequestHandler<GetPaymentMethodsQuery, Result<IReadOnlyList<SavedCardDto>>>
{
    public async Task<Result<IReadOnlyList<SavedCardDto>>> Handle(
        GetPaymentMethodsQuery query, CancellationToken ct)
    {
        // EnsureCustomer creates the record if it doesn't exist yet.
        // Calling list immediately after will return an empty set for new customers.
        var customerId = await paymentService.EnsureCustomerAsync(query.UserId, ct);
        var methods    = await paymentService.ListPaymentMethodsAsync(customerId, ct);

        return Result<IReadOnlyList<SavedCardDto>>.Success(methods);
    }
}
