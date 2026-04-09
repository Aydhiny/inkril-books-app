using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Reference table — book genres (e.g. Horror, Sci-Fi, Fantasy).
/// Counts as a reference table, not toward the 10-table minimum.
/// </summary>
public class Genre : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    // Navigation
    public ICollection<BookGenre> BookGenres { get; set; } = [];
}
