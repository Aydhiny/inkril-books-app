using System.Net;
using System.Text.Json;
using FluentValidation;

namespace Inkril.API.Middleware;

/// <summary>
/// Global exception handler — maps known exception types to HTTP responses.
/// This means controllers never need try/catch blocks for domain errors.
///
/// Mapping:
///   ValidationException  → 400 Bad Request  (FluentValidation failures)
///   UnauthorizedAccessException → 401
///   KeyNotFoundException → 404
///   Everything else      → 500 (details hidden in production)
/// </summary>
public class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (ValidationException ex)
        {
            await WriteErrorAsync(context, HttpStatusCode.BadRequest,
                "Validation failed.",
                ex.Errors.Select(e => e.ErrorMessage));
        }
        catch (UnauthorizedAccessException ex)
        {
            logger.LogWarning("Unauthorized: {Message}", ex.Message);
            await WriteErrorAsync(context, HttpStatusCode.Unauthorized, "Unauthorized.");
        }
        catch (KeyNotFoundException ex)
        {
            await WriteErrorAsync(context, HttpStatusCode.NotFound, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception");
            var message = context.RequestServices
                .GetRequiredService<IHostEnvironment>().IsDevelopment()
                ? ex.ToString()
                : "An unexpected error occurred. Please try again later.";
            await WriteErrorAsync(context, HttpStatusCode.InternalServerError, message);
        }
    }

    private static async Task WriteErrorAsync(
        HttpContext context, HttpStatusCode status,
        string title, IEnumerable<string>? errors = null)
    {
        context.Response.StatusCode = (int)status;
        // RFC 7807 — application/problem+json tells clients this is a structured
        // error object, not a raw API payload. Swagger renders it correctly and
        // mobile clients can distinguish error envelopes from success bodies.
        context.Response.ContentType = "application/problem+json";

        var body = JsonSerializer.Serialize(new
        {
            type   = "https://tools.ietf.org/html/rfc7807",
            title,
            status = (int)status,
            errors = errors?.ToArray() ?? (string[])[]
        }, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });

        await context.Response.WriteAsync(body);
    }
}
