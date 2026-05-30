using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Books.Queries;

/// <summary>
/// Returns the storage path (read URL) for a book's PDF — but only if the requesting
/// user owns the book in their UserBooks library, or is an admin (desktop role).
///
/// This is the controlled read-access gate required by the professor's §3 note:
/// "the public catalog must not return the PDF read URL."
/// </summary>
public record GetBookReadUrlQuery(Guid BookId, Guid? RequestingUserId, bool IsAdmin)
    : IRequest<Result<string>>;

public class GetBookReadUrlQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetBookReadUrlQuery, Result<string>>
{
    public async Task<Result<string>> Handle(GetBookReadUrlQuery q, CancellationToken ct)
    {
        var book = await uow.Books.Query()
            .FirstOrDefaultAsync(b => b.Id == q.BookId && !b.IsDeleted, ct);

        if (book is null)
            return Result<string>.Failure("Book not found.");

        // Guard: a book exists in the DB but may not have an uploaded PDF yet
        if (string.IsNullOrWhiteSpace(book.FilePath))
            return Result<string>.Failure("No PDF is available for this book yet.");

        // Admins (desktop role) can access any book's file for management purposes
        if (q.IsAdmin)
            return Result<string>.Success(book.FilePath);

        // Regular users must own the book (have it in their library)
        if (q.RequestingUserId is null)
            return Result<string>.Failure("Authentication required.");

        var owns = await uow.UserBooks.AnyAsync(
            ub => ub.UserId == q.RequestingUserId && ub.BookId == q.BookId, ct);

        if (!owns)
            return Result<string>.Failure("You do not have access to this book. Add it to your library first.");

        return Result<string>.Success(book.FilePath);
    }
}
