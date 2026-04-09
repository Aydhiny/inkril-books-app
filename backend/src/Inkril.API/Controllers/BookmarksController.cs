using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Bookmarks.Commands;
using Inkril.Application.Features.Bookmarks.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/bookmarks")]
[Authorize]
public class BookmarksController(
    IMediator mediator,
    ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetForBook([FromQuery] Guid bookId, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        return Ok(await mediator.Send(new GetBookBookmarksQuery(userId, bookId), ct));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateBookmarkRequest req, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(
            new CreateBookmarkCommand(userId, req.BookId, req.PageNumber, req.HighlightedText, req.Note, req.Color), ct);
        return result.Succeeded
            ? Ok(new { id = result.Value })
            : BadRequest(new { errors = result.Errors });
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new DeleteBookmarkCommand(id, userId), ct);
        return result.Succeeded ? NoContent() : BadRequest(new { errors = result.Errors });
    }
}

public record CreateBookmarkRequest(
    Guid BookId,
    int PageNumber,
    string? HighlightedText,
    string? Note,
    string? Color);
