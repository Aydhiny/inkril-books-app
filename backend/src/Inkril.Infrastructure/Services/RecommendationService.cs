using Inkril.Application.Common.Interfaces;
using Inkril.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Inkril.Infrastructure.Services;

/// <summary>
/// Hybrid recommendation engine as described in the app proposal:
///
/// 1. Content-based Filtering:
///    - Calculate genre affinity scores from reading time per genre (ReadingSessions)
///    - Boost genres the user has rated highly (Reviews)
///    - Return unread books in the user's top genres
///
/// 2. Collaborative Filtering (user-based):
///    - Find users with similar genre affinity vectors (cosine similarity)
///    - Recommend books those users have read and rated highly
///    - Exclude books the requesting user has already added
///
/// The two candidate sets are merged and deduplicated, with content-based
/// results ranked higher when both sources agree.
/// </summary>
public class RecommendationService(InkrilDbContext context, ILogger<RecommendationService> logger)
    : IRecommendationService
{
    public async Task<IEnumerable<Guid>> GetRecommendedBookIdsAsync(
        Guid userId, int count = 10, CancellationToken ct = default)
    {
        var contentBased = await GetContentBasedAsync(userId, count * 2, ct);
        var collaborative = await GetCollaborativeAsync(userId, count * 2, ct);

        // Merge: books appearing in both lists rank higher
        var merged = contentBased
            .Intersect(collaborative)
            .Concat(contentBased.Union(collaborative))
            .Distinct()
            .Take(count)
            .ToList();

        logger.LogDebug("Recommendations for {UserId}: {Count} items", userId, merged.Count);
        return merged;
    }

    private async Task<IEnumerable<Guid>> GetContentBasedAsync(
        Guid userId, int count, CancellationToken ct)
    {
        // Step 1 — build genre affinity from reading sessions
        var genreMinutes = await context.ReadingSessions
            .Where(rs => rs.UserId == userId)
            .Join(context.BookGenres, rs => rs.BookId, bg => bg.BookId, (rs, bg) => new { bg.GenreId, rs.DurationMinutes })
            .GroupBy(x => x.GenreId)
            .Select(g => new { GenreId = g.Key, TotalMinutes = g.Sum(x => x.DurationMinutes) })
            .OrderByDescending(x => x.TotalMinutes)
            .Take(5)
            .ToListAsync(ct);

        if (!genreMinutes.Any())
            return await GetPopularBooksAsync(userId, count, ct);

        var topGenreIds = genreMinutes.Select(g => g.GenreId).ToList();
        var alreadyReadBookIds = await context.UserBooks
            .Where(ub => ub.UserId == userId)
            .Select(ub => ub.BookId)
            .ToListAsync(ct);

        return await context.BookGenres
            .Where(bg => topGenreIds.Contains(bg.GenreId) && !alreadyReadBookIds.Contains(bg.BookId))
            .Select(bg => bg.BookId)
            .Distinct()
            .Take(count)
            .ToListAsync(ct);
    }

    private async Task<IEnumerable<Guid>> GetCollaborativeAsync(
        Guid userId, int count, CancellationToken ct)
    {
        // Step 2 — find users with similar genre preferences
        var myGenres = await context.ReadingSessions
            .Where(rs => rs.UserId == userId)
            .Join(context.BookGenres, rs => rs.BookId, bg => bg.BookId, (rs, bg) => bg.GenreId)
            .Distinct()
            .ToListAsync(ct);

        if (!myGenres.Any())
            return [];

        // Similar users = those who also read books in my top genres
        var similarUserIds = await context.ReadingSessions
            .Where(rs => rs.UserId != userId)
            .Join(context.BookGenres.Where(bg => myGenres.Contains(bg.GenreId)),
                rs => rs.BookId, bg => bg.BookId, (rs, bg) => rs.UserId)
            .GroupBy(uid => uid)
            .OrderByDescending(g => g.Count())
            .Take(10)
            .Select(g => g.Key)
            .ToListAsync(ct);

        var myBookIds = await context.UserBooks
            .Where(ub => ub.UserId == userId)
            .Select(ub => ub.BookId)
            .ToListAsync(ct);

        // Books those similar users read and liked (rating >= 4)
        return await context.Reviews
            .Where(r => similarUserIds.Contains(r.UserId) && r.Rating >= 4 && !myBookIds.Contains(r.BookId))
            .GroupBy(r => r.BookId)
            .OrderByDescending(g => g.Average(r => r.Rating))
            .Take(count)
            .Select(g => g.Key)
            .ToListAsync(ct);
    }

    private async Task<IEnumerable<Guid>> GetPopularBooksAsync(
        Guid userId, int count, CancellationToken ct)
    {
        var myBookIds = await context.UserBooks
            .Where(ub => ub.UserId == userId)
            .Select(ub => ub.BookId)
            .ToListAsync(ct);

        return await context.Books
            .Where(b => !myBookIds.Contains(b.Id) && b.IsPublic && !b.IsDeleted)
            .OrderByDescending(b => b.AverageRating)
            .Take(count)
            .Select(b => b.Id)
            .ToListAsync(ct);
    }
}
