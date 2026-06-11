using System.Security.Claims;
using Inkril.Application.Common.Interfaces;
using Inkril.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace Inkril.API.Middleware;

/// <summary>
/// Guards the /uploads/books/ static path with per-book ownership verification.
/// Checks that the authenticated user has the book in their UserBooks library
/// AND (for premium books) has an active succeeded purchase.
/// Admins (desktop role) bypass the ownership check.
///
/// Placement: must run after UseAuthentication() so HttpContext.User is
/// populated before we resolve the ownership claim.
/// </summary>
public class BookFilesAuthorizationMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, IUnitOfWork uow)
    {
        if (!context.Request.Path.StartsWithSegments("/uploads/books",
                StringComparison.OrdinalIgnoreCase))
        {
            await next(context);
            return;
        }

        if (context.User.Identity is not { IsAuthenticated: true })
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsync("Unauthorized.");
            return;
        }

        // Admins can access any PDF (management use-case).
        if (context.User.IsInRole("desktop"))
        {
            await next(context);
            return;
        }

        // Extract book ID from path: /uploads/books/{bookId}.pdf
        var fileName = Path.GetFileNameWithoutExtension(
            context.Request.Path.Value?.Split('/').LastOrDefault() ?? "");

        if (!Guid.TryParse(fileName, out var bookId))
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsync("Forbidden.");
            return;
        }

        var userIdClaim = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdClaim, out var userId))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsync("Unauthorized.");
            return;
        }

        var owns = await uow.UserBooks.AnyAsync(
            ub => ub.UserId == userId && ub.BookId == bookId, default);

        if (!owns)
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsync("Forbidden.");
            return;
        }

        // For premium books also verify an active purchase (not refunded).
        var book = await uow.Books.Query()
            .FirstOrDefaultAsync(b => b.Id == bookId && !b.IsDeleted, default);

        if (book is { IsPremium: true })
        {
            var hasActivePurchase = await uow.Purchases.AnyAsync(
                p => p.UserId == userId && p.BookId == bookId
                  && p.Status == PurchaseStatus.Succeeded, default);

            if (!hasActivePurchase)
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                await context.Response.WriteAsync("Forbidden.");
                return;
            }
        }

        await next(context);
    }
}
