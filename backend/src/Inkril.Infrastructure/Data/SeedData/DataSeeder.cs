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
        await SeedLeaderboardUsersAsync();
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
            if (!result.Succeeded)
            {
                // Log the actual errors so silent failures are immediately visible in the console.
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                logger.LogError("Failed to seed user '{UserName}': {Errors}", u.UserName, errors);
                continue;
            }

            await userManager.AddToRoleAsync(user, u.Role);
            await context.UserSettings.AddAsync(new UserSettings { UserId = user.Id });
            logger.LogInformation("Seeded user: {UserName}", u.UserName);
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
        var fictionId   = context.Genres.First(g => g.Name == "Fiction").Id;
        var scifiId     = context.Genres.First(g => g.Name == "Science Fiction").Id;
        var romanceId   = context.Genres.First(g => g.Name == "Romance").Id;
        var selfHelpId  = context.Genres.First(g => g.Name == "Self-Help").Id;
        var historyId   = context.Genres.First(g => g.Name == "History").Id;
        var psychologyId = context.Genres.First(g => g.Name == "Psychology").Id;

        // Cover images via Open Library (free, no auth required)
        var coverMap = new Dictionary<string, string>
        {
            ["Moby Dick"]                       = "https://covers.openlibrary.org/b/isbn/9780142437247-L.jpg",
            ["1984"]                            = "https://covers.openlibrary.org/b/isbn/9780451524935-L.jpg",
            ["The Great Gatsby"]                = "https://covers.openlibrary.org/b/isbn/9780743273565-L.jpg",
            ["Pride and Prejudice"]             = "https://covers.openlibrary.org/b/isbn/9780141439518-L.jpg",
            ["Dune"]                            = "https://covers.openlibrary.org/b/isbn/9780441013593-L.jpg",
            ["The Alchemist"]                   = "https://covers.openlibrary.org/b/isbn/9780061122415-L.jpg",
            ["To Kill a Mockingbird"]           = "https://covers.openlibrary.org/b/isbn/9780446310789-L.jpg",
            ["The Little Prince"]               = "https://covers.openlibrary.org/b/isbn/9780156013987-L.jpg",
            // Premium books
            ["Atomic Habits"]                   = "https://covers.openlibrary.org/b/isbn/9780735211292-L.jpg",
            ["Sapiens"]                         = "https://covers.openlibrary.org/b/isbn/9780062316097-L.jpg",
            ["The Psychology of Money"]         = "https://covers.openlibrary.org/b/isbn/9780857197689-L.jpg",
            ["Deep Work"]                       = "https://covers.openlibrary.org/b/isbn/9781455586691-L.jpg",
            ["Thinking, Fast and Slow"]         = "https://covers.openlibrary.org/b/isbn/9780374533557-L.jpg",
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
                new() {
                    Title = "The Alchemist", Author = "Paulo Coelho",
                    Description = "A young shepherd's journey to find treasure and discover his Personal Legend.",
                    CoverImageUrl = coverMap["The Alchemist"],
                    FilePath = "/uploads/books/alchemist.pdf", TotalPages = 208,
                    FileSizeBytes = 1024 * 512,
                    PublishedDate = new DateTime(1988, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = fictionId }]
                },
                new() {
                    Title = "To Kill a Mockingbird", Author = "Harper Lee",
                    Description = "A powerful story of racial injustice and moral growth in the American South.",
                    CoverImageUrl = coverMap["To Kill a Mockingbird"],
                    FilePath = "/uploads/books/mockingbird.pdf", TotalPages = 336,
                    FileSizeBytes = 1024 * 768,
                    PublishedDate = new DateTime(1960, 7, 11, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = fictionId }]
                },
                new() {
                    Title = "The Little Prince", Author = "Antoine de Saint-Exupéry",
                    Description = "A beloved novella about love, loss, and the wisdom of childhood.",
                    CoverImageUrl = coverMap["The Little Prince"],
                    FilePath = "/uploads/books/little-prince.pdf", TotalPages = 96,
                    FileSizeBytes = 1024 * 256,
                    PublishedDate = new DateTime(1943, 4, 6, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = fictionId }]
                },

                // ── Premium books ─────────────────────────────────────────────
                new() {
                    Title = "Atomic Habits", Author = "James Clear",
                    Description = "An easy and proven way to build good habits and break bad ones. " +
                                  "Tiny changes, remarkable results — the #1 most-sold self-help book of the decade.",
                    CoverImageUrl = coverMap["Atomic Habits"],
                    FilePath = "/uploads/books/atomic-habits.pdf", TotalPages = 320,
                    FileSizeBytes = 1024 * 1024 * 6,
                    PublishedDate = new DateTime(2018, 10, 16, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true, IsPremium = true, Price = 4.99m,
                    BookGenres = [new BookGenre { GenreId = selfHelpId }]
                },
                new() {
                    Title = "Sapiens", Author = "Yuval Noah Harari",
                    Description = "A brief history of humankind — from the Stone Age to the AI Age. " +
                                  "How Homo sapiens came to dominate the planet and what the future holds.",
                    CoverImageUrl = coverMap["Sapiens"],
                    FilePath = "/uploads/books/sapiens.pdf", TotalPages = 443,
                    FileSizeBytes = 1024 * 1024 * 9,
                    PublishedDate = new DateTime(2011, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true, IsPremium = true, Price = 6.99m,
                    BookGenres = [new BookGenre { GenreId = historyId }]
                },
                new() {
                    Title = "The Psychology of Money", Author = "Morgan Housel",
                    Description = "Timeless lessons on wealth, greed, and happiness. " +
                                  "How your relationship with money shapes your financial decisions.",
                    CoverImageUrl = coverMap["The Psychology of Money"],
                    FilePath = "/uploads/books/psychology-of-money.pdf", TotalPages = 256,
                    FileSizeBytes = 1024 * 1024 * 5,
                    PublishedDate = new DateTime(2020, 9, 8, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true, IsPremium = true, Price = 3.99m,
                    BookGenres = [new BookGenre { GenreId = selfHelpId }]
                },
                new() {
                    Title = "Deep Work", Author = "Cal Newport",
                    Description = "Rules for focused success in a distracted world. " +
                                  "The ability to perform deep work is becoming both rarer and more valuable.",
                    CoverImageUrl = coverMap["Deep Work"],
                    FilePath = "/uploads/books/deep-work.pdf", TotalPages = 304,
                    FileSizeBytes = 1024 * 1024 * 5,
                    PublishedDate = new DateTime(2016, 1, 5, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true, IsPremium = true, Price = 4.99m,
                    BookGenres = [new BookGenre { GenreId = selfHelpId }]
                },
                new() {
                    Title = "Thinking, Fast and Slow", Author = "Daniel Kahneman",
                    Description = "Nobel Prize winner Daniel Kahneman explores the two systems of thought " +
                                  "that shape our judgements and reveals the flaws in human reasoning.",
                    CoverImageUrl = coverMap["Thinking, Fast and Slow"],
                    FilePath = "/uploads/books/thinking-fast-and-slow.pdf", TotalPages = 499,
                    FileSizeBytes = 1024 * 1024 * 10,
                    PublishedDate = new DateTime(2011, 10, 25, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true, IsPremium = true, Price = 5.99m,
                    BookGenres = [new BookGenre { GenreId = psychologyId }]
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
            var existingTitles = existing.Select(b => b.Title).ToHashSet();

            // Patch missing covers on already-seeded books
            foreach (var book in existing)
            {
                if (string.IsNullOrEmpty(book.CoverImageUrl) &&
                    coverMap.TryGetValue(book.Title, out var url))
                {
                    book.CoverImageUrl = url;
                    patched = true;
                }
            }

            // Add new books that weren't seeded in earlier runs
            var newBooks = new List<Book>();
            if (!existingTitles.Contains("The Alchemist"))
                newBooks.Add(new Book {
                    Title = "The Alchemist", Author = "Paulo Coelho",
                    Description = "A young shepherd's journey to find treasure and discover his Personal Legend.",
                    CoverImageUrl = coverMap["The Alchemist"],
                    FilePath = "/uploads/books/alchemist.pdf", TotalPages = 208,
                    FileSizeBytes = 1024 * 512,
                    PublishedDate = new DateTime(1988, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = fictionId }]
                });
            if (!existingTitles.Contains("To Kill a Mockingbird"))
                newBooks.Add(new Book {
                    Title = "To Kill a Mockingbird", Author = "Harper Lee",
                    Description = "A powerful story of racial injustice and moral growth in the American South.",
                    CoverImageUrl = coverMap["To Kill a Mockingbird"],
                    FilePath = "/uploads/books/mockingbird.pdf", TotalPages = 336,
                    FileSizeBytes = 1024 * 768,
                    PublishedDate = new DateTime(1960, 7, 11, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = fictionId }]
                });
            if (!existingTitles.Contains("The Little Prince"))
                newBooks.Add(new Book {
                    Title = "The Little Prince", Author = "Antoine de Saint-Exupéry",
                    Description = "A beloved novella about love, loss, and the wisdom of childhood.",
                    CoverImageUrl = coverMap["The Little Prince"],
                    FilePath = "/uploads/books/little-prince.pdf", TotalPages = 96,
                    FileSizeBytes = 1024 * 256,
                    PublishedDate = new DateTime(1943, 4, 6, 0, 0, 0, DateTimeKind.Utc),
                    IsPublic = true,
                    BookGenres = [new BookGenre { GenreId = fictionId }]
                });

            // Add premium books if not yet seeded
            var premiumTitles = new[]
            {
                ("Atomic Habits",             "James Clear",        selfHelpId,   true,  4.99m, "/uploads/books/atomic-habits.pdf",            320, (long)(1024 * 1024 * 6), new DateTime(2018, 10, 16, 0, 0, 0, DateTimeKind.Utc)),
                ("Sapiens",                   "Yuval Noah Harari",  historyId,    true,  6.99m, "/uploads/books/sapiens.pdf",                  443, (long)(1024 * 1024 * 9), new DateTime(2011,  1,  1, 0, 0, 0, DateTimeKind.Utc)),
                ("The Psychology of Money",   "Morgan Housel",      selfHelpId,   true,  3.99m, "/uploads/books/psychology-of-money.pdf",      256, (long)(1024 * 1024 * 5), new DateTime(2020,  9,  8, 0, 0, 0, DateTimeKind.Utc)),
                ("Deep Work",                 "Cal Newport",        selfHelpId,   true,  4.99m, "/uploads/books/deep-work.pdf",                304, (long)(1024 * 1024 * 5), new DateTime(2016,  1,  5, 0, 0, 0, DateTimeKind.Utc)),
                ("Thinking, Fast and Slow",   "Daniel Kahneman",    psychologyId, true,  5.99m, "/uploads/books/thinking-fast-and-slow.pdf",   499, (long)(1024 * 1024 * 10), new DateTime(2011, 10, 25, 0, 0, 0, DateTimeKind.Utc)),
            };

            foreach (var (title, author, genreId, isPremium, price, filePath, pages, size, pubDate) in premiumTitles)
            {
                if (!existingTitles.Contains(title))
                {
                    newBooks.Add(new Book
                    {
                        Title = title, Author = author,
                        CoverImageUrl = coverMap.TryGetValue(title, out var cu) ? cu : null,
                        FilePath = filePath, TotalPages = pages,
                        FileSizeBytes = size, PublishedDate = pubDate,
                        IsPublic = true, IsPremium = isPremium, Price = price,
                        BookGenres = [new BookGenre { GenreId = genreId }]
                    });
                }
                else
                {
                    // Patch existing premium books that pre-date the IsPremium/Price columns
                    var premBook = await context.Books
                        .FirstOrDefaultAsync(b => b.Title == title);
                    if (premBook is not null && !premBook.IsPremium)
                    {
                        premBook.IsPremium = isPremium;
                        premBook.Price     = price;
                        patched = true;
                    }
                }
            }

            if (newBooks.Count > 0)
            {
                await context.Books.AddRangeAsync(newBooks);
                patched = true;
                logger.LogInformation("Added {Count} new books to existing library", newBooks.Count);
            }

            if (patched) await context.SaveChangesAsync();
        }
    }

    /// <summary>
    /// Seeds fictional readers with realistic reading stats so the global
    /// leaderboard is never empty for a fresh install.
    /// Each user is created only once — idempotent on subsequent startups.
    /// </summary>
    private async Task SeedLeaderboardUsersAsync()
    {
        // Seed data: (username, firstName, lastName, totalMinutes, streakDays, booksCompleted)
        var dummies = new[]
        {
            ("elena_reads",  "Elena",   "Vasquez",   4520, 45, 12),
            ("kai_tanaka",   "Kai",     "Tanaka",    3890, 38,  9),
            ("mia_stormont", "Mia",     "Stormont",  3210, 30,  8),
            ("theo_b",       "Theo",    "Barker",    2760, 25,  7),
            ("sara_words",   "Sara",    "Okonkwo",   2340, 22,  6),
            ("jaden_reads",  "Jaden",   "Morales",   1980, 18,  5),
            ("lily_pages",   "Lily",    "Huang",     1650, 15,  4),
            ("omar_books",   "Omar",    "Farouk",    1320, 12,  3),
        };

        foreach (var (userName, first, last, totalMin, streak, books) in dummies)
        {
            // Skip if user already exists
            if (await userManager.FindByNameAsync(userName) is not null) continue;

            var user = new ApplicationUser
            {
                UserName = userName,
                Email = $"{userName}@inkril.app",
                FirstName = first,
                LastName = last,
                EmailConfirmed = true,
            };

            var result = await userManager.CreateAsync(user, "Inkril#2025!");
            if (!result.Succeeded) continue;

            await userManager.AddToRoleAsync(user, "mobile");
            await context.UserSettings.AddAsync(new UserSettings { UserId = user.Id });

            // Create DailyReadingStat rows spread across the past N days
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var minutesPerDay = totalMin / Math.Max(streak, 1);
            var rand = new Random(userName.GetHashCode());

            for (int day = 0; day < streak; day++)
            {
                var date = today.AddDays(-day);
                var variance = rand.Next(-5, 15);
                var minutes = Math.Max(1, minutesPerDay + variance);

                await context.DailyReadingStats.AddAsync(new DailyReadingStat
                {
                    UserId         = user.Id,
                    Date           = date,
                    MinutesRead    = minutes,
                    StreakDays     = streak - day,
                    BooksCompleted = day == 0 ? books : 0,
                });
            }

            logger.LogInformation("Seeded leaderboard user: {UserName}", userName);
        }

        await context.SaveChangesAsync();
    }
}
