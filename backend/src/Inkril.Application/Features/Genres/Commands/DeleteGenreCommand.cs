using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Genres.Commands;

public record DeleteGenreCommand(Guid Id) : IRequest<Result>;

public class DeleteGenreCommandHandler(IUnitOfWork uow)
    : IRequestHandler<DeleteGenreCommand, Result>
{
    public async Task<Result> Handle(DeleteGenreCommand cmd, CancellationToken ct)
    {
        var genre = await uow.Genres.GetByIdAsync(cmd.Id, ct);
        if (genre is null)
            return Result.Failure("Genre not found.");

        // Prevent deleting genres that are still assigned to books —
        // a soft-delete of the genre would silently break those books' genre lists.
        var inUse = await uow.Books.Query()
            .AnyAsync(b => b.BookGenres.Any(bg => bg.GenreId == cmd.Id) && !b.IsDeleted, ct);

        if (inUse)
            return Result.Failure("Cannot delete this genre because it is assigned to one or more books. Remove it from all books first.");

        uow.Genres.SoftDelete(genre);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
