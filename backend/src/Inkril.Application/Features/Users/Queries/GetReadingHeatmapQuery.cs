using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Users.Queries;

/// <summary>
/// Returns one <see cref="HeatmapDayDto"/> per calendar day in <paramref name="Year"/>
/// that has a <see cref="DailyReadingStat"/> row — zero-minute days are omitted so the
/// payload stays small. The Flutter calendar widget fills missing days with grey.
/// </summary>
public record HeatmapDayDto(DateOnly Date, int MinutesRead);

public record GetReadingHeatmapQuery(Guid UserId, int Year)
    : IRequest<Result<IEnumerable<HeatmapDayDto>>>;

public class GetReadingHeatmapQueryHandler(IUnitOfWork uow)
    : IRequestHandler<GetReadingHeatmapQuery, Result<IEnumerable<HeatmapDayDto>>>
{
    public async Task<Result<IEnumerable<HeatmapDayDto>>> Handle(
        GetReadingHeatmapQuery q, CancellationToken ct)
    {
        var yearStart = new DateOnly(q.Year, 1, 1);
        var yearEnd   = new DateOnly(q.Year, 12, 31);

        var stats = await uow.DailyReadingStats.FindAsync(
            s => s.UserId == q.UserId
              && s.Date >= yearStart
              && s.Date <= yearEnd,
            ct);

        var result = stats
            .Where(s => s.MinutesRead > 0)
            .Select(s => new HeatmapDayDto(s.Date, s.MinutesRead))
            .OrderBy(d => d.Date);

        return Result<IEnumerable<HeatmapDayDto>>.Success(result);
    }
}
