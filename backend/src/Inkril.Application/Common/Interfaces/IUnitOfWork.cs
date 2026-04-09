using Inkril.Domain.Entities;

namespace Inkril.Application.Common.Interfaces;

/// <summary>
/// Unit of Work — wraps all repositories under a single DB transaction.
/// Ensures atomicity: either all changes in a command are saved or none are.
/// </summary>
public interface IUnitOfWork : IDisposable
{
    IRepository<Book> Books { get; }
    IRepository<UserBook> UserBooks { get; }
    IRepository<ReadingSession> ReadingSessions { get; }
    IRepository<Bookmark> Bookmarks { get; }
    IRepository<Review> Reviews { get; }
    IRepository<Friendship> Friendships { get; }
    IRepository<FriendRequest> FriendRequests { get; }
    IRepository<Notification> Notifications { get; }
    IRepository<UserSettings> UserSettings { get; }
    IRepository<DailyReadingStat> DailyReadingStats { get; }
    IRepository<Genre> Genres { get; }

    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
