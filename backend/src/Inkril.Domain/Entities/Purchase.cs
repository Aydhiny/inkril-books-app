using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Records a completed Stripe payment for a premium book.
/// Table 11 — extends the 10-table minimum with payment history.
/// </summary>
public class Purchase : BaseEntity
{
    public Guid UserId { get; set; }

    public Guid BookId { get; set; }

    /// <summary>Stripe PaymentIntent ID (pi_…). Used to reconcile with the Stripe dashboard.</summary>
    public string StripePaymentIntentId { get; set; } = string.Empty;

    /// <summary>Amount charged in the smallest currency unit (e.g. cents for USD).</summary>
    public long AmountCents { get; set; }

    public string Currency { get; set; } = "usd";

    /// <summary>pending → succeeded | failed. Mirrors Stripe PaymentIntent status.</summary>
    public string Status { get; set; } = "pending";

    public DateTime? PaidAt { get; set; }

    // Navigation
    public ApplicationUser User { get; set; } = null!;
    public Book Book { get; set; } = null!;
}
