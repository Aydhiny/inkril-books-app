namespace Inkril.API.Middleware;

/// <summary>
/// Guards the /uploads/books/ static path so that only authenticated users can
/// download PDF files directly. This is a defence-in-depth layer: the primary
/// gate is GET /api/books/{id}/read-url (ownership check), but without this
/// middleware a user who knows (or guesses) the filename can fetch the PDF
/// directly via the static-files middleware, bypassing ownership entirely.
///
/// Cover images (/uploads/covers/) remain public — they are not sensitive.
///
/// Placement: must run after app.UseAuthentication() so HttpContext.User is
/// already populated from the JWT by the time we evaluate IsAuthenticated.
/// </summary>
public class BookFilesAuthorizationMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Path.StartsWithSegments("/uploads/books",
                StringComparison.OrdinalIgnoreCase))
        {
            if (context.User.Identity is not { IsAuthenticated: true })
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                await context.Response.WriteAsync("Unauthorized.");
                return;
            }
        }

        await next(context);
    }
}
