using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Auth.Commands;
using Inkril.Domain.Entities;
using Inkril.Infrastructure.Data;
using Inkril.Infrastructure.Data.Repositories;
using Inkril.Infrastructure.Data.SeedData;
using Inkril.Infrastructure.Messaging;
using Inkril.Infrastructure.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;

namespace Inkril.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, IConfiguration config)
    {
        // ── Database ──────────────────────────────────────────────────────
        services.AddDbContext<InkrilDbContext>(opt =>
            opt.UseNpgsql(config.GetConnectionString("Default")
               ?? throw new InvalidOperationException("ConnectionStrings:Default not configured")));

        // ── ASP.NET Identity ──────────────────────────────────────────────
        // AddIdentityCore instead of AddIdentity so that cookie auth is NOT
        // registered as the default scheme — JWT (configured in Program.cs)
        // stays the default, meaning [Authorize] challenges return 401 not
        // a redirect to /Account/Login.
        services.AddIdentityCore<ApplicationUser>(opt =>
        {
            opt.Password.RequireNonAlphanumeric = false;
            opt.Password.RequireUppercase = false;
            opt.Password.RequiredLength = 6;
            opt.User.RequireUniqueEmail = true;
        })
        .AddRoles<IdentityRole<Guid>>()
        .AddEntityFrameworkStores<InkrilDbContext>()
        .AddDefaultTokenProviders();

        // ── Repositories / UoW ───────────────────────────────────────────
        services.AddScoped<IUnitOfWork, UnitOfWork>();

        // ── Services ─────────────────────────────────────────────────────
        services.AddScoped<ICurrentUserService, CurrentUserService>();
        services.AddScoped<IEmailService, EmailService>();
        services.AddScoped<IRecommendationService, RecommendationService>();
        services.AddScoped<ITokenService, TokenService>();
        services.AddScoped<IPaymentService, StripePaymentService>();

        // ── Messaging (RabbitMQ) ─────────────────────────────────────────
        services.AddSingleton<IMessagePublisher, RabbitMqPublisher>();

        // ── Redis (caching leaderboard etc.) ─────────────────────────────
        var redisConn = config["Redis:ConnectionString"];
        if (!string.IsNullOrEmpty(redisConn))
            services.AddSingleton<IConnectionMultiplexer>(_ => ConnectionMultiplexer.Connect(redisConn));

        // ── In-process response cache (leaderboard, recommendations) ─────────
        // IMemoryCache is process-local — fine for a single container. If the
        // app scales horizontally, swap GetOrCreateAsync calls to use the Redis
        // IConnectionMultiplexer already registered above.
        services.AddMemoryCache();

        // ── Seed data ─────────────────────────────────────────────────────
        services.AddScoped<DataSeeder>();

        return services;
    }
}
