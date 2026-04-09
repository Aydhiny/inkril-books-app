using Inkril.Application.Common.Interfaces;
using Inkril.Domain.Entities;
using Inkril.Infrastructure.Data;

namespace Inkril.Infrastructure.Data.Repositories;

public class UnitOfWork(InkrilDbContext context) : IUnitOfWork
{
    private IRepository<Book>? _books;
    private IRepository<UserBook>? _userBooks;
    private IRepository<ReadingSession>? _readingSessions;
    private IRepository<Bookmark>? _bookmarks;
    private IRepository<Review>? _reviews;
    private IRepository<Friendship>? _friendships;
    private IRepository<FriendRequest>? _friendRequests;
    private IRepository<Notification>? _notifications;
    private IRepository<UserSettings>? _userSettings;
    private IRepository<DailyReadingStat>? _dailyReadingStats;
    private IRepository<Genre>? _genres;

    public IRepository<Book> Books => _books ??= new Repository<Book>(context);
    public IRepository<UserBook> UserBooks => _userBooks ??= new Repository<UserBook>(context);
    public IRepository<ReadingSession> ReadingSessions => _readingSessions ??= new Repository<ReadingSession>(context);
    public IRepository<Bookmark> Bookmarks => _bookmarks ??= new Repository<Bookmark>(context);
    public IRepository<Review> Reviews => _reviews ??= new Repository<Review>(context);
    public IRepository<Friendship> Friendships => _friendships ??= new Repository<Friendship>(context);
    public IRepository<FriendRequest> FriendRequests => _friendRequests ??= new Repository<FriendRequest>(context);
    public IRepository<Notification> Notifications => _notifications ??= new Repository<Notification>(context);
    public IRepository<UserSettings> UserSettings => _userSettings ??= new Repository<UserSettings>(context);
    public IRepository<DailyReadingStat> DailyReadingStats => _dailyReadingStats ??= new Repository<DailyReadingStat>(context);
    public IRepository<Genre> Genres => _genres ??= new Repository<Genre>(context);

    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
        => await context.SaveChangesAsync(ct);

    public void Dispose() => context.Dispose();
}
