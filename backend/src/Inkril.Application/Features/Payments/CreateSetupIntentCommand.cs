using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Payments;

/// <summary>
/// Creates a Stripe SetupIntent so the mobile client can save a card without charging it.
/// The returned secrets initialise the Payment Sheet in "setup" mode.
/// </summary>
public record CreateSetupIntentCommand(Guid UserId) : IRequest<Result<SetupIntentDto>>;

public record SetupIntentDto(
    string SetupIntentClientSecret,
    string StripeCustomerId,
    string EphemeralKeySecret);

public class CreateSetupIntentCommandValidator : AbstractValidator<CreateSetupIntentCommand>
{
    public CreateSetupIntentCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public class CreateSetupIntentCommandHandler(IPaymentService paymentService)
    : IRequestHandler<CreateSetupIntentCommand, Result<SetupIntentDto>>
{
    public async Task<Result<SetupIntentDto>> Handle(
        CreateSetupIntentCommand cmd, CancellationToken ct)
    {
        var customerId = await paymentService.EnsureCustomerAsync(cmd.UserId, ct);

        var (setupClientSecret, ephemeralKey) =
            await paymentService.CreateSetupContextAsync(customerId, ct);

        return Result<SetupIntentDto>.Success(
            new SetupIntentDto(setupClientSecret, customerId, ephemeralKey));
    }
}
