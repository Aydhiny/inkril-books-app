using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Users.Queries;

public record UserDto(
    Guid Id, string UserName, string Email, string FirstName,
    string LastName, string? ProfilePhotoUrl, bool IsBlocked,
    DateTime CreatedAt, IEnumerable<string> Roles);

public record GetUsersQuery(
    string? SearchTerm,
    bool? IsBlocked,
    int PageNumber = 1,
    int PageSize = 20
) : IRequest<PagedList<UserDto>>;

public class GetUsersQueryHandler(UserManager<ApplicationUser> userManager)
    : IRequestHandler<GetUsersQuery, PagedList<UserDto>>
{
    public async Task<PagedList<UserDto>> Handle(GetUsersQuery q, CancellationToken ct)
    {
        var query = userManager.Users.Where(u => !u.IsDeleted);

        if (!string.IsNullOrWhiteSpace(q.SearchTerm))
            query = query.Where(u => u.UserName!.Contains(q.SearchTerm) ||
                                     u.Email!.Contains(q.SearchTerm) ||
                                     u.FirstName.Contains(q.SearchTerm) ||
                                     u.LastName.Contains(q.SearchTerm));

        if (q.IsBlocked.HasValue)
            query = query.Where(u => u.IsBlocked == q.IsBlocked);

        var totalCount = await query.CountAsync(ct);
        var users = await query
            .OrderBy(u => u.UserName)
            .Skip((q.PageNumber - 1) * q.PageSize)
            .Take(q.PageSize)
            .ToListAsync(ct);

        var dtos = new List<UserDto>();
        foreach (var u in users)
        {
            var roles = await userManager.GetRolesAsync(u);
            dtos.Add(new UserDto(u.Id, u.UserName!, u.Email!, u.FirstName, u.LastName,
                u.ProfilePhotoUrl, u.IsBlocked, u.CreatedAt, roles));
        }

        return new PagedList<UserDto>(dtos, totalCount, q.PageNumber, q.PageSize);
    }
}
