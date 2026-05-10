using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.UserBooks.Commands;
using Inkril.Application.Features.UserBooks.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/user-books")]
[Authorize]
public class UserBooksController(IMediator mediator, ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetLibrary(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        return Ok(await mediator.Send(new GetUserLibraryQuery(userId, pageNumber, pageSize), ct));
    }

    [HttpPost]
    public async Task<IActionResult> AddToLibrary([FromBody] AddToLibraryRequest req, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new AddBookToLibraryCommand(userId, req.BookId), ct);
        return result.Succeeded
            ? Ok(new { id = result.Value })
            : BadRequest(new { errors = result.Errors });
    }

    /// <summary>
    /// Lightweight mid-session progress sync. Called by the reader on page turns (debounced ~5 s).
    /// Persists current page + computed progress % so the user resumes from the right page
    /// even if the app is force-killed before the session formally ends.
    /// </summary>
    [HttpPatch("{bookId:guid}/progress")]
    public async Task<IActionResult> UpdateProgress(Guid bookId, [FromBody] UpdateProgressRequest req, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new UpdateReadingProgressCommand(userId, bookId, req.CurrentPage), ct);
        return result.Succeeded ? Ok() : BadRequest(new { errors = result.Errors });
    }

    /// <summary>
    /// Returns progress data for friends who have the same book in their library.
    /// Powers the buddy-reading overlay in the mobile reader.
    /// </summary>
    [HttpGet("{bookId:guid}/friends-progress")]
    public async Task<IActionResult> GetFriendsProgress(Guid bookId, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new GetFriendsProgressQuery(userId, bookId), ct);
        return result.Succeeded ? Ok(result.Value) : BadRequest(new { errors = result.Errors });
    }
}

public record AddToLibraryRequest(Guid BookId);
public record UpdateProgressRequest(int CurrentPage);
