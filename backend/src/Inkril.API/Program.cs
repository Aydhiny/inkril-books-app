using System.Text;
using FluentValidation;
using Inkril.API.Infrastructure;
using Inkril.API.Middleware;
using Inkril.Application.Common.Behaviors;
using Inkril.Infrastructure;
using Inkril.Infrastructure.Data.SeedData;
using MediatR;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// ── Structured logging (Serilog) ──────────────────────────────────────────────
// Reads sink/level configuration from appsettings.json under "Serilog" key.
// Structured properties (UserId, CommandType, DurationMs) are emitted by
// LoggingBehavior so every request is traceable without touching controller code.
builder.Host.UseSerilog((ctx, lc) => lc
    .ReadFrom.Configuration(ctx.Configuration)
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Application", "Inkril.API"));

// ── Configuration is loaded from appsettings.json + environment variables ────
// No secrets are hardcoded. See .env.example for required env vars.

builder.Services.AddControllers();
// Enables the RFC 7807 ProblemDetails format for ValidationProblem() / Problem()
// calls in controllers. Without this, ASP.NET 8 falls back to its own format.
builder.Services.AddProblemDetails();
builder.Services.AddEndpointsApiExplorer();

// ── Swagger with JWT support ──────────────────────────────────────────────────
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Inkril API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "Enter: Bearer {token}",
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
            []
        }
    });
});

// ── Infrastructure (DB, Identity, RabbitMQ, etc.) ────────────────────────────
builder.Services.AddInfrastructure(builder.Configuration);

// ── MediatR + Pipeline Behaviors ─────────────────────────────────────────────
builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssembly(typeof(Inkril.Application.Features.Auth.Commands.LoginCommand).Assembly);
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
});

builder.Services.AddValidatorsFromAssembly(typeof(Inkril.Application.Features.Auth.Commands.LoginCommand).Assembly);

// ── JWT Authentication ────────────────────────────────────────────────────────
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        var key = builder.Configuration["Jwt:Key"]
            ?? throw new InvalidOperationException("Jwt:Key not configured");

        opt.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
            ValidateIssuer = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidateAudience = true,
            ValidAudience = builder.Configuration["Jwt:Audience"],
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddHttpContextAccessor();

// ── CORS (allow Flutter dev origins) ──────────────────────────────────────────
builder.Services.AddCors(opt =>
    opt.AddPolicy("AllowAll", p => p
        .AllowAnyOrigin()
        .AllowAnyMethod()
        .AllowAnyHeader()));

var app = builder.Build();

// ── Seed database ─────────────────────────────────────────────────────────────
using (var scope = app.Services.CreateScope())
{
    var seeder = scope.ServiceProvider.GetRequiredService<DataSeeder>();
    await seeder.SeedAsync();
}

app.UseMiddleware<ExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// HTTPS termination is handled by the reverse proxy in production.
// Kestrel runs plain HTTP inside Docker on port 8080.
app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();

// ── Static files: serve uploaded PDFs and covers ──────────────────────────
// BookFilesAuthorizationMiddleware must run after UseAuthentication (so the JWT
// is already resolved into HttpContext.User) and before UseStaticFiles (so the
// file is never served to unauthenticated requests).  Covers are public; only
// the /uploads/books/ subtree is protected.
var uploadsPath = Path.Combine(app.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(uploadsPath);
PlaceholderPdfGenerator.Generate(uploadsPath);   // idempotent: skips existing files
app.UseMiddleware<BookFilesAuthorizationMiddleware>();
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(uploadsPath),
    RequestPath = "/uploads",
    // ServeUnknownFileTypes removed — only .pdf and image types are uploaded,
    // all of which are recognised MIME types in ASP.NET's default provider.
});

app.MapControllers();

app.Run();
