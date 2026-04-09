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
}

public record AddToLibraryRequest(Guid BookId);
