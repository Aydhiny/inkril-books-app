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
///    - Reason: "Because you read [genre name]"
///
/// 2. Collaborative Filtering (user-based):
///    - Find users with similar genre affinity vectors (cosine similarity)
///    - Recommend books those users have read and rated highly
///    - Reason: "Readers with similar taste enjoyed this"
///
/// The two candidate sets are merged and deduplicated, with content-based
/// results ranked higher when both sources agree.
/// </summary>
public class RecommendationService(InkrilDbContext context, ILogger<RecommendationService> logger)
    : IRecommendationService
{
    public async Task<IEnumerable<BookRecommendation>> GetRecommendedBooksAsync(
        Guid userId, int count = 10, CancellationToken ct = default)
    {
        var contentBased = await GetContentBasedAsync(userId, count * 2, ct);
        var collaborative = await GetCollaborativeAsync(userId, count * 2, ct);

        // Books appearing in both lists rank first; content-based reason is more informative so keep it.
        var contentIds = contentBased.Select(r => r.BookId).ToHashSet();
        var collaborativeIds = collaborative.Select(r => r.BookId).ToHashSet();

        var merged = contentBased
            .Concat(collaborative.Where(r => !contentIds.Contains(r.BookId)))
            .DistinctBy(r => r.BookId)
            // Items that appear in both sources bubble to the top
            .OrderByDescending(r => collaborativeIds.Contains(r.BookId) && contentIds.Contains(r.BookId))
            .Take(count)
            .ToList();

        logger.LogDebug("Recommendations for {UserId}: {Count} items", userId, merged.Count);
        return merged;
    }

    private async Task<IEnumerable<BookRecommendation>> GetContentBasedAsync(
        Guid userId, int count, CancellationToken ct)
    {
        // Step 1 — build genre affinity from reading sessions; join genre names for the reason string
        var genreAffinity = await context.ReadingSessions
            .Where(rs => rs.UserId == userId)
            .Join(context.BookGenres, rs => rs.BookId, bg => bg.BookId, (rs, bg) => new { bg.GenreId, rs.DurationMinutes })
            .GroupBy(x => x.GenreId)
            .Select(g => new { GenreId = g.Key, TotalMinutes = g.Sum(x => x.DurationMinutes) })
            .OrderByDescending(x => x.TotalMinutes)
            .Take(5)
            .Join(context.Genres, g => g.GenreId, genre => genre.Id, (g, genre) => new { g.GenreId, g.TotalMinutes, GenreName = genre.Name })
            .ToListAsync(ct);

        if (!genreAffinity.Any())
            return await GetPopularBooksAsync(userId, count, ct);

        var topGenreIds = genreAffinity.Select(g => g.GenreId).ToList();
        // Map genre ID → name for the reason string
        var genreNames = genreAffinity.ToDictionary(g => g.GenreId, g => g.GenreName);

        var alreadyReadBookIds = await context.UserBooks
            .Where(ub => ub.UserId == userId)
            .Select(ub => ub.BookId)
            .ToListAsync(ct);

        // For each candidate book, pick the first matching genre as the reason
        var candidates = await context.BookGenres
            .Where(bg => topGenreIds.Contains(bg.GenreId) && !alreadyReadBookIds.Contains(bg.BookId))
            .Select(bg => new { bg.BookId, bg.GenreId })
            .Distinct()
            .Take(count)
            .ToListAsync(ct);

        // Group by book and pick the highest-affinity genre as the reason
        return candidates
            .GroupBy(c => c.BookId)
            .Select(g =>
            {
                // Pick the genre with highest affinity (lowest index in topGenreIds = highest ranked)
                var bestGenreId = g
                    .Select(c => c.GenreId)
                    .OrderBy(id => topGenreIds.IndexOf(id))
                    .First();
                var reasonGenre = genreNames.TryGetValue(bestGenreId, out var name) ? name : "your favourite genres";
                return new BookRecommendation(g.Key, $"Because you read {reasonGenre}");
            })
            .ToList();
    }

    private async Task<IEnumerable<BookRecommendation>> GetCollaborativeAsync(
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
        var bookIds = await context.Reviews
            .Where(r => similarUserIds.Contains(r.UserId) && r.Rating >= 4 && !myBookIds.Contains(r.BookId))
            .GroupBy(r => r.BookId)
            .OrderByDescending(g => g.Average(r => r.Rating))
            .Take(count)
            .Select(g => g.Key)
            .ToListAsync(ct);

        return bookIds.Select(id =>
            new BookRecommendation(id, "Readers with similar taste enjoyed this"));
    }

    private async Task<IEnumerable<BookRecommendation>> GetPopularBooksAsync(
        Guid userId, int count, CancellationToken ct)
    {
        var myBookIds = await context.UserBooks
            .Where(ub => ub.UserId == userId)
            .Select(ub => ub.BookId)
            .ToListAsync(ct);

        var bookIds = await context.Books
            .Where(b => !myBookIds.Contains(b.Id) && b.IsPublic && !b.IsDeleted)
            .OrderByDescending(b => b.AverageRating)
            .Take(count)
            .Select(b => b.Id)
            .ToListAsync(ct);

        return bookIds.Select(id => new BookRecommendation(id, "Popular on Inkril"));
    }
}
