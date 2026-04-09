using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Reviews.Commands;
using Inkril.Application.Features.Reviews.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/books/{bookId:guid}/reviews")]
public class ReviewsController(IMediator mediator, ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetReviews(
        Guid bookId,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10,
        CancellationToken ct = default)
        => Ok(await mediator.Send(new GetBookReviewsQuery(bookId, pageNumber, pageSize), ct));

    [HttpPost]
    [Authorize]
    public async Task<IActionResult> CreateReview(
        Guid bookId,
        [FromBody] CreateReviewRequest req,
        CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new CreateReviewCommand(userId, bookId, req.Rating, req.Comment), ct);
        return result.Succeeded
            ? Ok(new { id = result.Value })
            : BadRequest(new { errors = result.Errors });
    }
}

public record CreateReviewRequest(int Rating, string? Comment);
