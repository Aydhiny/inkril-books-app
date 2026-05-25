using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Payments;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController(IMediator mediator, ICurrentUserService currentUser)
    : ApiControllerBase
{
    /// <summary>
    /// Creates a Stripe PaymentIntent for a premium book and returns the client_secret
    /// that the mobile app passes to flutter_stripe's Payment Sheet.
    /// </summary>
    [HttpPost("create-intent")]
    public async Task<IActionResult> CreateIntent(
        [FromBody] CreateIntentRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is null)
            return Unauthorized();

        var result = await mediator.Send(
            new CreatePaymentIntentCommand(request.BookId, currentUser.UserId.Value), ct);

        return ToResult(result, dto => Ok(dto));
    }

    /// <summary>
    /// Called by the mobile app after the Payment Sheet reports success.
    /// Verifies the PaymentIntent status with Stripe, then marks the Purchase as succeeded
    /// and adds the book to the user's library.
    /// </summary>
    [HttpPost("confirm")]
    public async Task<IActionResult> Confirm(
        [FromBody] ConfirmRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is null)
            return Unauthorized();

        var result = await mediator.Send(
            new ConfirmPurchaseCommand(request.PaymentIntentId, currentUser.UserId.Value), ct);

        return ToResult(result, Ok());
    }

    /// <summary>
    /// Returns all books the current user has successfully purchased.
    /// </summary>
    [HttpGet("my-purchases")]
    public async Task<IActionResult> GetMyPurchases(CancellationToken ct)
    {
        if (currentUser.UserId is null)
            return Unauthorized();

        var result = await mediator.Send(
            new GetUserPurchasesQuery(currentUser.UserId.Value), ct);

        return Ok(result);
    }

    // ── Saved payment methods ─────────────────────────────────────────────────

    /// <summary>
    /// Creates a Stripe SetupIntent so the mobile app can save a card without charging it.
    /// Returns the client_secret, Stripe Customer ID, and EphemeralKey needed to
    /// initialise the flutter_stripe Payment Sheet in setup mode.
    /// </summary>
    [HttpPost("setup-intent")]
    public async Task<IActionResult> CreateSetupIntent(CancellationToken ct)
    {
        if (currentUser.UserId is null)
            return Unauthorized();

        var result = await mediator.Send(
            new CreateSetupIntentCommand(currentUser.UserId.Value), ct);

        return ToResult(result, dto => Ok(dto));
    }

    /// <summary>
    /// Returns all saved card-type PaymentMethods attached to the current user's Stripe Customer.
    /// </summary>
    [HttpGet("payment-methods")]
    public async Task<IActionResult> GetPaymentMethods(CancellationToken ct)
    {
        if (currentUser.UserId is null)
            return Unauthorized();

        var result = await mediator.Send(
            new GetPaymentMethodsQuery(currentUser.UserId.Value), ct);

        return ToResult(result, dto => Ok(dto));
    }

    /// <summary>
    /// Detaches (removes) a saved PaymentMethod from the current user's Stripe Customer.
    /// </summary>
    [HttpDelete("payment-methods/{paymentMethodId}")]
    public async Task<IActionResult> RemovePaymentMethod(
        string paymentMethodId, CancellationToken ct)
    {
        if (currentUser.UserId is null)
            return Unauthorized();

        var result = await mediator.Send(
            new RemovePaymentMethodCommand(currentUser.UserId.Value, paymentMethodId), ct);

        return ToResult(result, Ok());
    }

    // ── Refunds ───────────────────────────────────────────────────────────────

    /// <summary>
    /// Issues a full refund for the caller's own purchase.
    /// Transitions the purchase: Succeeded|PartiallyRefunded → Refunded.
    /// </summary>
    [HttpPost("refund")]
    public async Task<IActionResult> Refund(
        [FromBody] RefundRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is null)
            return Unauthorized();

        var result = await mediator.Send(
            new RefundPurchaseCommand(request.PaymentIntentId, currentUser.UserId.Value), ct);

        return ToResult(result, Ok());
    }

    /// <summary>
    /// Issues a partial refund for the caller's own purchase.
    /// Transitions the purchase: Succeeded → PartiallyRefunded, or
    /// PartiallyRefunded → PartiallyRefunded | Refunded depending on coverage.
    /// </summary>
    [HttpPost("partial-refund")]
    public async Task<IActionResult> PartialRefund(
        [FromBody] PartialRefundRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is null)
            return Unauthorized();

        var result = await mediator.Send(
            new PartialRefundPurchaseCommand(
                request.PaymentIntentId,
                request.AmountCents,
                currentUser.UserId.Value), ct);

        return ToResult(result, dto => Ok(dto));
    }
}

// ── Request DTOs ──────────────────────────────────────────────────────────────

public record CreateIntentRequest(Guid BookId);
public record ConfirmRequest(string PaymentIntentId);
public record RefundRequest(string PaymentIntentId);
public record PartialRefundRequest(string PaymentIntentId, long AmountCents);
