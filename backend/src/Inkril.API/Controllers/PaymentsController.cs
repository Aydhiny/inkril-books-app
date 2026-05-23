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
    /// Used by the mobile My Purchases list and to determine which books show a price badge.
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
}

// ── Request DTOs ──────────────────────────────────────────────────────────────

public record CreateIntentRequest(Guid BookId);
public record ConfirmRequest(string PaymentIntentId);
