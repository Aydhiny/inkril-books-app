using Inkril.Application.Common.Interfaces;
using MediatR;

namespace Inkril.Application.Features.Genres.Queries;

public record GenreDto(Guid Id, string Name, string? Description);

public record GetGenresQuery : IRequest<IEnumerable<GenreDto>>;

public class GetGenresQueryHandler(IUnitOfWork uow) : IRequestHandler<GetGenresQuery, IEnumerable<GenreDto>>
{
    public async Task<IEnumerable<GenreDto>> Handle(GetGenresQuery q, CancellationToken ct)
    {
        var genres = await uow.Genres.GetAllAsync(ct);
        return genres
            .Where(g => !g.IsDeleted)
            .OrderBy(g => g.Name)
            .Select(g => new GenreDto(g.Id, g.Name, g.Description));
    }
}
