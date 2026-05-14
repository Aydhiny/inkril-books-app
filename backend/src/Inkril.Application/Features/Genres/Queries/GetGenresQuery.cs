using Inkril.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Genres.Queries;

public record GenreDto(Guid Id, string Name, string? Description);

public record GetGenresQuery : IRequest<IEnumerable<GenreDto>>;

public class GetGenresQueryHandler(IUnitOfWork uow) : IRequestHandler<GetGenresQuery, IEnumerable<GenreDto>>
{
    public async Task<IEnumerable<GenreDto>> Handle(GetGenresQuery q, CancellationToken ct)
    {
        // Push the soft-delete filter to the database — avoids materialising the full
        // genres table into memory before filtering (§16: filtering must happen in DB).
        return await uow.Genres.Query()
            .Where(g => !g.IsDeleted)
            .OrderBy(g => g.Name)
            .Select(g => new GenreDto(g.Id, g.Name, g.Description))
            .ToListAsync(ct);
    }
}
