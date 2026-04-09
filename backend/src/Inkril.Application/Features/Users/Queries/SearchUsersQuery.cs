using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Users.Queries;

public record SearchUserDto(Guid Id, string UserName, string? ProfilePhotoUrl);

public record SearchUsersQuery(string Term, int Limit = 20) : IRequest<IEnumerable<SearchUserDto>>;

public class SearchUsersQueryHandler(UserManager<ApplicationUser> userManager)
    : IRequestHandler<SearchUsersQuery, IEnumerable<SearchUserDto>>
{
    public async Task<IEnumerable<SearchUserDto>> Handle(SearchUsersQuery q, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(q.Term))
            return [];

        return await userManager.Users
            .Where(u => !u.IsDeleted && !u.IsBlocked &&
                        (u.UserName!.Contains(q.Term) ||
                         u.FirstName.Contains(q.Term) ||
                         u.LastName.Contains(q.Term)))
            .Take(q.Limit)
            .Select(u => new SearchUserDto(u.Id, u.UserName!, u.ProfilePhotoUrl))
            .ToListAsync(ct);
    }
}
