using Inkril.Domain.Common;

namespace Inkril.Domain.Entities;

/// <summary>
/// Core entity — table 1 of 10.
/// Represents a book in the public or private library.
/// </summary>
public class Book : BaseEntity
{
    public string Title { get; set; } = string.Empty;

    public string Author { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? CoverImageUrl { get; set; }

    /// <summary>PDF file path or cloud storage URL.</summary>
    public string FilePath { get; set; } = string.Empty;

    public long FileSizeBytes { get; set; }

    public int TotalPages { get; set; }

    public DateTime PublishedDate { get; set; }

    public string? ISBN { get; set; }

    public string? Publisher { get; set; }

    public string? Language { get; set; } = "en";

    /// <summary>Public books appear in the shared library; private books are user-uploaded.</summary>
    public bool IsPublic { get; set; } = true;

    public bool IsActive { get; set; } = true;

    public double AverageRating { get; set; } = 0;

    public int RatingCount { get; set; } = 0;

    // Navigation
    public ICollection<BookGenre> BookGenres { get; set; } = [];
    public ICollection<UserBook> UserBooks { get; set; } = [];
    public ICollection<ReadingSession> ReadingSessions { get; set; } = [];
    public ICollection<Bookmark> Bookmarks { get; set; } = [];
    public ICollection<Review> Reviews { get; set; } = [];
}
