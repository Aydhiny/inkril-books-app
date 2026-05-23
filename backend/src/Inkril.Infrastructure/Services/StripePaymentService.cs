using Inkril.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Stripe;

namespace Inkril.Infrastructure.Services;

/// <summary>
/// Stripe implementation of IPaymentService.
/// Uses Stripe.net to create and verify PaymentIntents.
///
/// Configuration (appsettings.json / environment):
///   Stripe:SecretKey  — sk_test_… (test) or sk_live_… (production)
/// </summary>
public class StripePaymentService : IPaymentService
{
    public StripePaymentService(IConfiguration config)
    {
        var secretKey = config["Stripe:SecretKey"]
            ?? throw new InvalidOperationException("Stripe:SecretKey not configured.");
        StripeConfiguration.ApiKey = secretKey;
    }

    /// <inheritdoc />
    public async Task<(string ClientSecret, string PaymentIntentId)> CreatePaymentIntentAsync(
        long amountCents, string currency, string description, CancellationToken ct = default)
    {
        var options = new PaymentIntentCreateOptions
        {
            Amount      = amountCents,
            Currency    = currency,
            Description = description,
            // automatic_payment_methods lets Stripe decide which payment methods
            // to show based on the customer's locale and currency. Works for cards.
            AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
            {
                Enabled = true,
            },
        };

        var service = new PaymentIntentService();
        var intent  = await service.CreateAsync(options, cancellationToken: ct);

        return (intent.ClientSecret, intent.Id);
    }

    /// <inheritdoc />
    public async Task<bool> IsPaymentSucceededAsync(
        string paymentIntentId, CancellationToken ct = default)
    {
        var service = new PaymentIntentService();
        var intent  = await service.GetAsync(paymentIntentId, cancellationToken: ct);
        return intent.Status == "succeeded";
    }
}
