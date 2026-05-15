using Inkril.Application.Features.Reports.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "desktop")]
public class ReportsController(IMediator mediator) : ApiControllerBase
{
    /// <summary>Dashboard stats for the admin desktop app.</summary>
    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard([FromQuery] int days = 14, CancellationToken ct = default)
        => Ok(await mediator.Send(new GetDashboardStatsQuery(days), ct));
}
