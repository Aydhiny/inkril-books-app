namespace Inkril.Domain.Enums;

/// <summary>
/// Lifecycle states for a <see cref="Entities.Purchase"/>.
///
/// Valid transitions (enforced by <c>Purchase.Transition()</c>):
///
/// <code>
///   Pending ──► Succeeded ──► Refunded          (terminal)
///      │              └──► PartiallyRefunded ──► Refunded
///      └──► Failed                               (terminal)
/// </code>
///
/// PartiallyRefunded → PartiallyRefunded is also legal when a second partial
/// refund is issued before the remainder is covered.
/// </summary>
public enum PurchaseStatus
{
    Pending,
    Succeeded,
    Failed,
    Refunded,
    PartiallyRefunded,
}
