namespace Inkril.Application.Common.Interfaces;

public interface IRecommendationService
{
    /// <summary>
    /// Hybrid recommendation: Content-based (genre affinity from reading time + ratings)
    /// combined with Collaborative Filtering (users with similar reading patterns).
    /// </summary>
    Task<IEnumerable<Guid>> GetRecommendedBookIdsAsync(Guid userId, int count = 10, CancellationToken ct = default);
}
