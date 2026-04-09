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
        if (await context.Books.AnyAsync()) return;

        var fictionGenreId = context.Genres.First(g => g.Name == "Fiction").Id;
        var scifiGenreId = context.Genres.First(g => g.Name == "Science Fiction").Id;

        var books = new List<Book>
        {
            new() { Title = "The Great Gatsby", Author = "F. Scott Fitzgerald",
                    Description = "A classic American novel set in the Jazz Age.",
                    FilePath = "/uploads/books/great-gatsby.pdf", TotalPages = 180,
                    FileSizeBytes = 1024 * 512, PublishedDate = new DateTime(1925, 4, 10),
                    IsPublic = true, BookGenres = [new BookGenre { GenreId = fictionGenreId }] },
            new() { Title = "Dune", Author = "Frank Herbert",
                    Description = "An epic science fiction saga on the desert planet Arrakis.",
                    FilePath = "/uploads/books/dune.pdf", TotalPages = 688,
                    FileSizeBytes = 1024 * 1024 * 2, PublishedDate = new DateTime(1965, 8, 1),
                    IsPublic = true, BookGenres = [new BookGenre { GenreId = scifiGenreId }] },
        };

        await context.Books.AddRangeAsync(books);
        await context.SaveChangesAsync();
        logger.LogInformation("Seeded {Count} books", books.Count);
    }
}
