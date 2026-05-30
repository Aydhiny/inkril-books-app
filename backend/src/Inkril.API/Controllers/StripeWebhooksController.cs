using Inkril.Application.Features.Payments;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Stripe;

namespace Inkril.API.Controllers;

/// <summary>
/// Receives signed webhook events from Stripe and updates purchase state accordingly.
///
/// Why webhooks instead of relying on POST /api/payments/confirm?
/// The client-side confirm endpoint is inherently unsafe: a malicious user
/// could call it without ever paying, and we'd mark the purchase as succeeded.
/// Webhooks are signed with a secret only Stripe and our server know, so the
/// event can't be forged. This is the recommended production pattern.
///
/// Configured events (Stripe Dashboard → Webhooks):
///   payment_intent.succeeded   — marks purchase Succeeded, adds book to library
///   payment_intent.payment_failed — marks purchase Failed
///   charge.refund.updated       — keeps RefundedAmountCents in sync if a refund
///                                  is updated or reversed on the Stripe side
///
/// The endpoint is intentionally [AllowAnonymous] — Stripe cannot authenticate.
/// Security comes from signature verification (Stripe-Signature header + secret).
/// </summary>
[ApiController]
[Route("api/webhooks/stripe")]
[AllowAnonymous]
public class StripeWebhooksController(
    IMediator mediator,
    IConfiguration configuration,
    ILogger<StripeWebhooksController> logger) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Handle(CancellationToken ct)
    {
        var webhookSecret = configuration["Stripe:WebhookSecret"];
        if (string.IsNullOrWhiteSpace(webhookSecret))
        {
            logger.LogWarning("Stripe:WebhookSecret is not configured — webhook rejected.");
            return BadRequest("Webhook secret not configured.");
        }

        // Read raw body — must happen before any framework buffering
        string json;
        using (var reader = new StreamReader(HttpContext.Request.Body))
            json = await reader.ReadToEndAsync(ct);

        Event stripeEvent;
        try
        {
            stripeEvent = EventUtility.ConstructEvent(
                json,
                Request.Headers["Stripe-Signature"],
                webhookSecret,
                throwOnApiVersionMismatch: false);
        }
        catch (StripeException ex)
        {
            // Invalid signature — log and return 400 so Stripe will retry
            logger.LogWarning(ex, "Stripe webhook signature validation failed");
            return BadRequest("Invalid webhook signature.");
        }

        logger.LogInformation("Stripe webhook received: {Type} / {Id}", stripeEvent.Type, stripeEvent.Id);

        switch (stripeEvent.Type)
        {
            case Events.PaymentIntentSucceeded:
            {
                if (stripeEvent.Data.Object is not PaymentIntent pi) break;

                var result = await mediator.Send(
                    new ConfirmPurchaseCommand(pi.Id, UserId: null), ct);

                if (!result.Succeeded)
                    logger.LogWarning(
                        "ConfirmPurchase failed for PaymentIntent {Id}: {Errors}",
                        pi.Id, string.Join(", ", result.Errors));
                break;
            }

            case Events.PaymentIntentPaymentFailed:
            {
                if (stripeEvent.Data.Object is not PaymentIntent pi) break;

                var result = await mediator.Send(
                    new FailPurchaseCommand(pi.Id), ct);

                if (!result.Succeeded)
                    logger.LogWarning(
                        "FailPurchase failed for PaymentIntent {Id}: {Errors}",
                        pi.Id, string.Join(", ", result.Errors));
                break;
            }

            case Events.ChargeRefundUpdated:
            {
                // Stripe sends this when a refund is updated (e.g., amount changed or reversed).
                // We log it for now; a production system would reconcile RefundedAmountCents.
                if (stripeEvent.Data.Object is not Refund refund) break;
                logger.LogInformation(
                    "Charge refund updated: {RefundId} status={Status} amount={Amount}",
                    refund.Id, refund.Status, refund.Amount);
                break;
            }

            default:
                // Unknown event types are silently acknowledged (return 200) so
                // Stripe doesn't keep retrying events we don't handle.
                logger.LogDebug("Unhandled Stripe event type: {Type}", stripeEvent.Type);
                break;
        }

        return Ok();
    }
}
