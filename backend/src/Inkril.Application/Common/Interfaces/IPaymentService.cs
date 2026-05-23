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
    /// Pass <paramref name="stripeCustomerId"/> to link the intent to a saved customer
    /// so their stored cards appear as a default payment option in the sheet.
    /// </summary>
    Task<(string ClientSecret, string PaymentIntentId)> CreatePaymentIntentAsync(
        long amountCents, string currency, string description,
        string? stripeCustomerId = null, CancellationToken ct = default);

    /// <summary>
    /// Retrieves the PaymentIntent from Stripe and confirms its status is "succeeded".
    /// </summary>
    Task<bool> IsPaymentSucceededAsync(string paymentIntentId, CancellationToken ct = default);

    // ── Saved payment methods ─────────────────────────────────────────────────

    /// <summary>
    /// Returns the Stripe Customer ID for the given user, creating one if it does not
    /// yet exist and persisting it to <c>ApplicationUser.StripeCustomerId</c>.
    /// </summary>
    Task<string> EnsureCustomerAsync(Guid userId, CancellationToken ct = default);

    /// <summary>
    /// Creates a short-lived EphemeralKey scoped to the given Stripe Customer.
    /// Required by the mobile Payment Sheet to let Stripe list and manage
    /// the customer's saved payment methods client-side.
    /// </summary>
    Task<string> CreateEphemeralKeyAsync(string stripeCustomerId, CancellationToken ct = default);

    /// <summary>
    /// Creates a SetupIntent (to save a card without charging) and an EphemeralKey
    /// for the given customer in a single round-trip.
    /// Returns the SetupIntent client secret and the EphemeralKey secret.
    /// </summary>
    Task<(string SetupIntentClientSecret, string EphemeralKeySecret)> CreateSetupContextAsync(
        string stripeCustomerId, CancellationToken ct = default);

    /// <summary>
    /// Lists all card-type PaymentMethods attached to the given Stripe Customer.
    /// </summary>
    Task<IReadOnlyList<SavedCardDto>> ListPaymentMethodsAsync(
        string stripeCustomerId, CancellationToken ct = default);

    /// <summary>
    /// Detaches a PaymentMethod from its customer so it is no longer saved.
    /// </summary>
    Task DetachPaymentMethodAsync(string paymentMethodId, CancellationToken ct = default);
}

/// <summary>DTO representing one saved card returned from Stripe.</summary>
public record SavedCardDto(
    string Id,
    string Brand,
    string Last4,
    int ExpMonth,
    int ExpYear);
