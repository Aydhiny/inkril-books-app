namespace Inkril.Application.Common.Interfaces;

/// <summary>
/// A single recommendation with the book ID and a human-readable explanation
/// of why this book was recommended (required by §2.4 — explainable recommendations).
/// </summary>
public record BookRecommendation(Guid BookId, string Reason);

public interface IRecommendationService
{
    /// <summary>
    /// Hybrid recommendation: Content-based (genre affinity from reading time + ratings)
    /// combined with Collaborative Filtering (users with similar reading patterns).
    /// Each result carries a Reason string explaining the recommendation to the user.
    /// </summary>
    Task<IEnumerable<BookRecommendation>> GetRecommendedBooksAsync(Guid userId, int count = 10, CancellationToken ct = default);
}
