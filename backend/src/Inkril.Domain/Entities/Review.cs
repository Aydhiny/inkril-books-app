using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Table 5 of 10 — a user's review and star rating for a book.
/// Also feeds the recommendation system (Content-based filtering signal).
/// </summary>
public class Review : BaseEntity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public Guid BookId { get; set; }
    public Book Book { get; set; } = null!;

    /// <summary>1–5 stars.</summary>
    public int Rating { get; set; }

    public string? Comment { get; set; }

    public bool IsEdited { get; set; } = false;
}
