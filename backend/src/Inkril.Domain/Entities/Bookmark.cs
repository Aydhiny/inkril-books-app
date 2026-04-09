using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Table 4 of 10 — a user's bookmark or highlight in a book.
/// Shown in the book detail screen and within the PDF reader.
/// </summary>
public class Bookmark : BaseEntity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public Guid BookId { get; set; }
    public Book Book { get; set; } = null!;

    public int PageNumber { get; set; }

    /// <summary>Optional text selected/highlighted by the user.</summary>
    public string? HighlightedText { get; set; }

    /// <summary>Optional note added alongside the bookmark.</summary>
    public string? Note { get; set; }

    public string? Color { get; set; } = "#FFD700";
}
