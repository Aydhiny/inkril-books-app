using Inkril.Domain.Common;
using Inkril.Domain.Enums;

namespace Inkril.Domain.Entities;

/// <summary>
/// Records a Stripe payment for a premium book.
/// Table 11 — extends the 10-table minimum with payment history.
///
/// Status transitions are enforced by <see cref="Transition"/> — calling code
/// must never set <see cref="Status"/> directly after construction.
/// </summary>
public class Purchase : BaseEntity
{
    public Guid UserId { get; set; }

    public Guid BookId { get; set; }

    /// <summary>Stripe PaymentIntent ID (pi_…). Used to reconcile with the Stripe dashboard.</summary>
    public string StripePaymentIntentId { get; set; } = string.Empty;

    /// <summary>Amount originally charged in the smallest currency unit (cents for USD).</summary>
    public long AmountCents { get; set; }

    /// <summary>Cumulative amount refunded so far (0 until a refund is issued).</summary>
    public long RefundedAmountCents { get; set; } = 0;

    public string Currency { get; set; } = "usd";

    /// <summary>
    /// Current lifecycle state. Use <see cref="Transition"/> to advance it —
    /// direct assignment bypasses state-machine validation and is intentionally
    /// private to callers outside this class.
    /// </summary>
    public PurchaseStatus Status { get; private set; } = PurchaseStatus.Pending;

    /// <summary>Stripe Refund ID of the most recent refund, if any.</summary>
    public string? StripeRefundId { get; set; }

    public DateTime? PaidAt { get; set; }

    // Navigation
    public ApplicationUser User { get; set; } = null!;
    public Book Book { get; set; } = null!;

    // ── State machine ─────────────────────────────────────────────────────────

    /// <summary>
    /// Advances the purchase to <paramref name="to"/>, enforcing the allowed
    /// transition table.  Throws <see cref="InvalidOperationException"/> on any
    /// invalid (or missing) edge.
    /// </summary>
    public void Transition(PurchaseStatus to)
    {
        var allowed = (Status, to) switch
        {
            // Happy path
            (PurchaseStatus.Pending,          PurchaseStatus.Succeeded)         => true,
            (PurchaseStatus.Pending,          PurchaseStatus.Failed)            => true,

            // Refund paths
            (PurchaseStatus.Succeeded,        PurchaseStatus.Refunded)          => true,
            (PurchaseStatus.Succeeded,        PurchaseStatus.PartiallyRefunded) => true,

            // Multiple partial refunds before full coverage
            (PurchaseStatus.PartiallyRefunded, PurchaseStatus.PartiallyRefunded) => true,

            // Final partial refund covers the remainder
            (PurchaseStatus.PartiallyRefunded, PurchaseStatus.Refunded)         => true,

            // All other edges — including anything from terminal states — are invalid
            _ => false,
        };

        if (!allowed)
            throw new InvalidOperationException(
                $"Invalid purchase status transition: {Status} → {to}.");

        Status = to;
    }
}
