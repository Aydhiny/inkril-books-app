using Inkril.Domain.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Inkril.Infrastructure.Data.SeedData;

/// <summary>
/// Seeds test data on startup (migrations only — no hardcoded prod data).
/// Credentials as required by the professor:
///   desktop / test (Admin role)
///   mobile  / test (mobile role)
/// </summary>
public class DataSeeder(
    InkrilDbContext context,
    UserManager<ApplicationUser> userManager,
    RoleManager<IdentityRole<Guid>> roleManager,
    ILogger<DataSeeder> logger)
{
    public async Task SeedAsync()
    {
        await context.Database.MigrateAsync();

        await SeedRolesAsync();
        await SeedUsersAsync();
        await SeedGenresAsync();
        await SeedBooksAsync();
    }

    private async Task SeedRolesAsync()
    {
        foreach (var role in new[] { "desktop", "mobile" })
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole<Guid>(role));
                logger.LogInformation("Created role: {Role}", role);
            }
        }
    }

    private async Task SeedUsersAsync()
    {
        var usersToSeed = new[]
        {
            new { UserName = "desktop", Email = "desktop@inkril.app", Password = "test",
                  FirstName = "Admin", LastName = "User", Role = "desktop" },
            new { UserName = "mobile", Email = "mobile@inkril.app", Password = "test",
                  FirstName = "Mobile", LastName = "User", Role = "mobile" },
        };

        foreach (var u in usersToSeed)
        {
            if (await userManager.FindByNameAsync(u.UserName) is not null) continue;

            var user = new ApplicationUser
            {
                UserName = u.UserName,
                Email = u.Email,
                FirstName = u.FirstName,
                LastName = u.LastName,
                EmailConfirmed = true
            };

            var result = await userManager.CreateAsync(user, u.Password);
            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(user, u.Role);
                await context.UserSettings.AddAsync(new UserSettings { UserId = user.Id });
                logger.LogInformation("Seeded user: {UserName}", u.UserName);
            }
        }

        await context.SaveChangesAsync();
    }

    private async Task SeedGenresAsync()
    {
        if (await context.Genres.AnyAsync()) return;

        var genres = new[]
        {
            "Fiction", "Non-Fiction", "Science Fiction", "Fantasy", "Horror",
            "Mystery", "Thriller", "Romance", "Biography", "History",
            "Self-Help", "Technology", "Philosophy", "Psychology"
        };

        await context.Genres.AddRangeAsync(genres.Select(g => new Genre { Name = g }));
        await context.SaveChangesAsync();
    }

    private async Task SeedBooksAsync()
    {
        var fictionId = context.Genres.First(g => g.Name == "Fiction").Id;
        var scifiId   = context.Genres.First(g => g.Name == "Science Fiction").Id;
        var romanceId = context.Genres.First(g => g.Name == "Romance").Id;

        // Cover images via Open Library (free, no auth required)
        var coverMap = new Dictionary<string, string>
        {
            ["Moby Dick"]           = "https://covers.openlibrary.org/b/isbn/9780142437247-L.jpg",
            ["1984"]                = "https://covers.openlibrary.org/b/isbn/9780451524935-L.jpg",
            ["The Great Gatsby"]    = "https://covers.openlibrary.org/b/isbn/9780743273565-L.jpg",
            ["Pride and Prejudice"] = "https://covers.openlibrary.org/b/isbn/9780141439518-L.jpg",
            ["Dune"]                = "https://covers.openlibrary.org/b/isbn/9780441013593-L.jpg",
        };

        if (!await context.Books.AnyAsync())
        {
            var books = new List<Book>
            {
                new() {
                    Title = "Moby Dick", Author = "Herman Melville",
                    Description = "The obsessive quest of Captain Ahab against the white whale.",
                    CoverImageUrl = coverMap["Moby Dick"],
                    FilePath = "/uploads/books/moby-dick.pdf", TotalPages = 635,
                    FileSizeBytes = 1024 * 1024 * 12,
                    PublishedDate = new DateTime(1851, 10, 18, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = fictionId }]
                },
                new() {
                    Title = "1984", Author = "George Orwell",
                    Description = "A dystopian novel about totalitarian surveillance society.",
                    CoverImageUrl = coverMap["1984"],
                    FilePath = "/uploads/books/1984.pdf", TotalPages = 328,
                    FileSizeBytes = 1024 * 1024 * 8,
                    PublishedDate = new DateTime(1949, 6, 8, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = scifiId }]
                },
                new() {
                    Title = "The Great Gatsby", Author = "F. Scott Fitzgerald",
                    Description = "A Jazz Age tale of wealth, love, and the American Dream.",
                    CoverImageUrl = coverMap["The Great Gatsby"],
                    FilePath = "/uploads/books/great-gatsby.pdf", TotalPages = 180,
                    FileSizeBytes = 1024 * 512,
                    PublishedDate = new DateTime(1925, 4, 10, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = fictionId }]
                },
                new() {
                    Title = "Pride and Prejudice", Author = "Jane Austen",
                    Description = "A witty romantic comedy of manners in Regency England.",
                    CoverImageUrl = coverMap["Pride and Prejudice"],
                    FilePath = "/uploads/books/pride-and-prejudice.pdf", TotalPages = 432,
                    FileSizeBytes = 1024 * 768,
                    PublishedDate = new DateTime(1813, 1, 28, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = romanceId }]
                },
                new() {
                    Title = "Dune", Author = "Frank Herbert",
                    Description = "An epic science fiction saga on the desert planet Arrakis.",
                    CoverImageUrl = coverMap["Dune"],
                    FilePath = "/uploads/books/dune.pdf", TotalPages = 688,
                    FileSizeBytes = 1024 * 1024 * 2,
                    PublishedDate = new DateTime(1965, 8, 1, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = scifiId }]
                },
            };

            await context.Books.AddRangeAsync(books);
            await context.SaveChangesAsync();
            logger.LogInformation("Seeded {Count} books", books.Count);
        }
        else
        {
            // Patch cover URLs for existing books that are missing them
            var existing = await context.Books.ToListAsync();
            bool patched = false;
            foreach (var book in existing)
            {
                if (string.IsNullOrEmpty(book.CoverImageUrl) &&
                    coverMap.TryGetValue(book.Title, out var url))
                {
                    book.CoverImageUrl = url;
                    patched = true;
                }
            }
            if (patched) await context.SaveChangesAsync();
        }
    }
}
