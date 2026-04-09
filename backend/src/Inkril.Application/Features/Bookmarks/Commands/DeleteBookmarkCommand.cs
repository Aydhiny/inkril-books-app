using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Bookmarks.Commands;

public record DeleteBookmarkCommand(Guid BookmarkId, Guid UserId) : IRequest<Result>;

public class DeleteBookmarkCommandHandler(IUnitOfWork uow)
    : IRequestHandler<DeleteBookmarkCommand, Result>
{
    public async Task<Result> Handle(DeleteBookmarkCommand cmd, CancellationToken ct)
    {
        var bookmark = await uow.Bookmarks.GetByIdAsync(cmd.BookmarkId, ct);
        if (bookmark is null || bookmark.UserId != cmd.UserId)
            return Result.Failure("Bookmark not found.");

        uow.Bookmarks.SoftDelete(bookmark);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
