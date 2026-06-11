using Inkril.Application.Common.Interfaces;
using Inkril.Domain.Entities;
using Inkril.Infrastructure.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Stripe;

namespace Inkril.Infrastructure.Services;

/// <summary>
/// Stripe implementation of IPaymentService.
///
/// Responsibilities:
///   • One-time book purchases  — PaymentIntent + confirm
///   • Saved payment methods    — Customer, SetupIntent, EphemeralKey, list/detach
///
/// Configuration (appsettings.json):
///   Stripe:SecretKey  — sk_test_… (test) or sk_live_… (production)
/// </summary>
public class StripePaymentService : IPaymentService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly InkrilDbContext _context;

    public StripePaymentService(
        IConfiguration config,
        UserManager<ApplicationUser> userManager,
        InkrilDbContext context)
    {
        var secretKey = config["Stripe:SecretKey"];
        if (string.IsNullOrWhiteSpace(secretKey))
            throw new InvalidOperationException(
                "Stripe:SecretKey is not configured. " +
                "Add it to appsettings.local.json under Stripe:SecretKey (sk_test_…).");
        StripeConfiguration.ApiKey = secretKey;

        _userManager = userManager;
        _context     = context;
    }

    // ── Purchase flow ─────────────────────────────────────────────────────────

    /// <inheritdoc />
    public async Task<(string ClientSecret, string PaymentIntentId)> CreatePaymentIntentAsync(
        long amountCents, string currency, string description,
        string? stripeCustomerId = null, CancellationToken ct = default)
    {
        var options = new PaymentIntentCreateOptions
        {
            Amount      = amountCents,
            Currency    = currency,
            Description = description,
            Customer    = stripeCustomerId, // null → Stripe ignores it gracefully
            AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
            {
                Enabled = true,
            },
        };

        var intent = await new PaymentIntentService().CreateAsync(options, cancellationToken: ct);
        return (intent.ClientSecret, intent.Id);
    }

    /// <inheritdoc />
    public async Task<bool> IsPaymentSucceededAsync(
        string paymentIntentId, CancellationToken ct = default)
    {
        var intent = await new PaymentIntentService().GetAsync(paymentIntentId, cancellationToken: ct);
        return intent.Status == "succeeded";
    }

    /// <inheritdoc />
    public async Task<(string ClientSecret, string PaymentIntentId)> RetrievePaymentIntentAsync(
        string paymentIntentId, CancellationToken ct = default)
    {
        var intent = await new PaymentIntentService().GetAsync(paymentIntentId, cancellationToken: ct);
        return (intent.ClientSecret, intent.Id);
    }

    // ── Saved payment methods ─────────────────────────────────────────────────

    /// <inheritdoc />
    /// Gets the user's Stripe Customer ID, creating and persisting one if needed.
    public async Task<string> EnsureCustomerAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString())
            ?? throw new InvalidOperationException($"User {userId} not found.");

        if (!string.IsNullOrEmpty(user.StripeCustomerId))
            return user.StripeCustomerId;

        // Create a new Stripe Customer tagged with the Inkril user ID for traceability.
        var customer = await new CustomerService().CreateAsync(new CustomerCreateOptions
        {
            Email    = user.Email,
            Name     = $"{user.FirstName} {user.LastName}".Trim(),
            Metadata = new Dictionary<string, string>
            {
                ["inkril_user_id"] = userId.ToString(),
            },
        }, cancellationToken: ct);

        // Persist directly via EF — we bypass UnitOfWork because ApplicationUser
        // is owned by ASP.NET Identity and is outside the domain repository pattern.
        await _context.Users
            .Where(u => u.Id == userId)
            .ExecuteUpdateAsync(
                s => s.SetProperty(u => u.StripeCustomerId, customer.Id), ct);

        return customer.Id;
    }

    /// <inheritdoc />
    public async Task<string> CreateEphemeralKeyAsync(
        string stripeCustomerId, CancellationToken ct = default)
    {
        // No explicit StripeVersion override — Stripe.net 45.x sets its built-in
        // API version which is compatible with flutter_stripe 10.x.
        var key = await new EphemeralKeyService().CreateAsync(
            new EphemeralKeyCreateOptions { Customer = stripeCustomerId },
            cancellationToken: ct);

        return key.Secret;
    }

    /// <inheritdoc />
    public async Task<(string SetupIntentClientSecret, string EphemeralKeySecret)> CreateSetupContextAsync(
        string stripeCustomerId, CancellationToken ct = default)
    {
        // Create both in parallel — they are independent Stripe calls.
        var keyTask    = CreateEphemeralKeyAsync(stripeCustomerId, ct);
        var intentTask = new SetupIntentService().CreateAsync(
            new SetupIntentCreateOptions
            {
                Customer           = stripeCustomerId,
                PaymentMethodTypes = ["card"],
            },
            cancellationToken: ct);

        await Task.WhenAll(keyTask, intentTask);

        return (intentTask.Result.ClientSecret, keyTask.Result);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<SavedCardDto>> ListPaymentMethodsAsync(
        string stripeCustomerId, CancellationToken ct = default)
    {
        var methods = await new PaymentMethodService().ListAsync(
            new PaymentMethodListOptions
            {
                Customer = stripeCustomerId,
                Type     = "card",
            },
            cancellationToken: ct);

        return methods.Data
            .Select(pm => new SavedCardDto(
                pm.Id,
                pm.Card.Brand,
                pm.Card.Last4,
                (int)pm.Card.ExpMonth,
                (int)pm.Card.ExpYear))
            .ToList();
    }

    /// <inheritdoc />
    public async Task DetachPaymentMethodAsync(
        string paymentMethodId, CancellationToken ct = default)
    {
        await new PaymentMethodService().DetachAsync(paymentMethodId, cancellationToken: ct);
    }

    // ── Refunds ───────────────────────────────────────────────────────────────

    /// <inheritdoc />
    public async Task<string> RefundPaymentAsync(
        string paymentIntentId, long? amountCents = null, CancellationToken ct = default)
    {
        var options = new RefundCreateOptions
        {
            PaymentIntent = paymentIntentId,
            Amount        = amountCents, // null → Stripe refunds the full remaining amount
        };

        var refund = await new RefundService().CreateAsync(options, cancellationToken: ct);
        return refund.Id;
    }
}
