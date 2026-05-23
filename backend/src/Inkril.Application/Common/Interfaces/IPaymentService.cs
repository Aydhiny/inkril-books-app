namespace Inkril.Application.Common.Interfaces;

/// <summary>
/// Abstraction over the Stripe payment gateway.
/// Application layer depends on this interface, not on Stripe.net directly,
/// keeping the inner layers free of third-party payment SDK references.
/// </summary>
public interface IPaymentService
{
    /// <summary>
    /// Creates a Stripe PaymentIntent for the given amount and returns the client secret
    /// that the mobile app uses to present the native Payment Sheet.
    /// </summary>
    Task<(string ClientSecret, string PaymentIntentId)> CreatePaymentIntentAsync(
        long amountCents, string currency, string description, CancellationToken ct = default);

    /// <summary>
    /// Retrieves the PaymentIntent from Stripe and confirms its status is "succeeded".
    /// Called server-side after the mobile client reports a successful Payment Sheet result.
    /// </summary>
    Task<bool> IsPaymentSucceededAsync(string paymentIntentId, CancellationToken ct = default);
}
