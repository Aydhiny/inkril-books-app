using Inkril.Domain.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Infrastructure.Data;

/// <summary>
/// Single EF Core DbContext for the main Inkril database.
/// Database name: 220088 (per professor requirement — named after student index number).
/// Uses IdentityDbContext so ASP.NET Identity tables are included automatically.
/// </summary>
public class InkrilDbContext(DbContextOptions<InkrilDbContext> options)
    : IdentityDbContext<ApplicationUser, IdentityRole<Guid>, Guid>(options)
{
    // ── Core tables (count toward 10-table minimum) ────────────────────────
    public DbSet<Book> Books => Set<Book>();
    public DbSet<UserBook> UserBooks => Set<UserBook>();
    public DbSet<ReadingSession> ReadingSessions => Set<ReadingSession>();
    public DbSet<Bookmark> Bookmarks => Set<Bookmark>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<FriendRequest> FriendRequests => Set<FriendRequest>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<UserSettings> UserSettings => Set<UserSettings>();
    public DbSet<DailyReadingStat> DailyReadingStats => Set<DailyReadingStat>();

    // ── Reference tables ──────────────────────────────────────────────────
    public DbSet<Genre> Genres => Set<Genre>();
    public DbSet<BookGenre> BookGenres => Set<BookGenre>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // ── BookGenre (many-to-many) ────────────────────────────────────
        builder.Entity<BookGenre>().HasKey(bg => new { bg.BookId, bg.GenreId });
        builder.Entity<BookGenre>()
            .HasOne(bg => bg.Book).WithMany(b => b.BookGenres).HasForeignKey(bg => bg.BookId);
        builder.Entity<BookGenre>()
            .HasOne(bg => bg.Genre).WithMany(g => g.BookGenres).HasForeignKey(bg => bg.GenreId);

        // ── UserBook ───────────────────────────────────────────────────
        builder.Entity<UserBook>()
            .HasIndex(ub => new { ub.UserId, ub.BookId }).IsUnique();

        // ── DailyReadingStat ───────────────────────────────────────────
        builder.Entity<DailyReadingStat>()
            .HasIndex(d => new { d.UserId, d.Date }).IsUnique();

        // ── Friendship (self-referencing) ──────────────────────────────
        builder.Entity<Friendship>()
            .HasOne(f => f.User)
            .WithMany(u => u.Friendships)
            .HasForeignKey(f => f.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Friendship>()
            .HasOne(f => f.Friend)
            .WithMany()
            .HasForeignKey(f => f.FriendId)
            .OnDelete(DeleteBehavior.Restrict);

        // ── FriendRequest ──────────────────────────────────────────────
        builder.Entity<FriendRequest>()
            .HasOne(r => r.Sender)
            .WithMany(u => u.SentFriendRequests)
            .HasForeignKey(r => r.SenderId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<FriendRequest>()
            .HasOne(r => r.Receiver)
            .WithMany(u => u.ReceivedFriendRequests)
            .HasForeignKey(r => r.ReceiverId)
            .OnDelete(DeleteBehavior.Restrict);

        // ── UserSettings (1-to-1) ──────────────────────────────────────
        builder.Entity<UserSettings>()
            .HasOne(s => s.User)
            .WithOne(u => u.Settings)
            .HasForeignKey<UserSettings>(s => s.UserId);

        // ── Soft-delete global query filters ──────────────────────────
        builder.Entity<Book>().HasQueryFilter(b => !b.IsDeleted);
        builder.Entity<UserBook>().HasQueryFilter(ub => !ub.IsDeleted);
        builder.Entity<ReadingSession>().HasQueryFilter(rs => !rs.IsDeleted);
        builder.Entity<Bookmark>().HasQueryFilter(bm => !bm.IsDeleted);
        builder.Entity<Review>().HasQueryFilter(r => !r.IsDeleted);
        builder.Entity<Friendship>().HasQueryFilter(f => !f.IsDeleted);
        builder.Entity<FriendRequest>().HasQueryFilter(fr => !fr.IsDeleted);
        builder.Entity<Notification>().HasQueryFilter(n => !n.IsDeleted);
        builder.Entity<DailyReadingStat>().HasQueryFilter(d => !d.IsDeleted);

        // ── Required fields NOT NULL ───────────────────────────────────
        builder.Entity<Book>().Property(b => b.Title).IsRequired().HasMaxLength(300);
        builder.Entity<Book>().Property(b => b.Author).IsRequired().HasMaxLength(200);
        builder.Entity<ApplicationUser>().Property(u => u.FirstName).IsRequired().HasMaxLength(100);
        builder.Entity<ApplicationUser>().Property(u => u.LastName).IsRequired().HasMaxLength(100);
    }

    public override Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        UpdateAuditFields();
        return base.SaveChangesAsync(ct);
    }

    private void UpdateAuditFields()
    {
        foreach (var entry in ChangeTracker.Entries<Domain.Common.BaseEntity>())
        {
            if (entry.State == EntityState.Modified)
                entry.Entity.UpdatedAt = DateTime.UtcNow;
        }
    }
}
