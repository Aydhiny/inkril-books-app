using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Friends.Commands;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FriendsController(
    IMediator mediator,
    IUnitOfWork uow,
    ICurrentUserService currentUser) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetFriends(CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var friendships = await uow.Friendships.FindAsync(f => f.UserId == userId, ct);
        return Ok(friendships.Select(f => new { f.FriendId, f.FriendsSince }));
    }

    [HttpPost("requests")]
    public async Task<IActionResult> SendRequest([FromBody] SendFriendRequestDto dto, CancellationToken ct)
    {
        var senderId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new SendFriendRequestCommand(senderId, dto.ReceiverId), ct);
        return ToResult(result, Ok());
    }

    [HttpGet("requests/pending")]
    public async Task<IActionResult> GetPendingRequests(CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var pending = await uow.FriendRequests.FindAsync(
            r => r.ReceiverId == userId && r.Status == Domain.Entities.FriendRequestStatus.Pending, ct);
        return Ok(pending.Select(r => new { r.Id, r.SenderId, r.CreatedAt }));
    }

    [HttpPut("requests/{id:guid}/respond")]
    public async Task<IActionResult> Respond(Guid id, [FromBody] RespondToRequestDto dto, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();
        var result = await mediator.Send(new RespondToFriendRequestCommand(id, userId, dto.Accept), ct);
        return ToResult(result, NoContent());
    }
}

public record SendFriendRequestDto(Guid ReceiverId);
public record RespondToRequestDto(bool Accept);
