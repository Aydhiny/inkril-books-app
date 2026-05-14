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
    private const int MaxPageSize = 100;

    public async Task<PagedList<UserDto>> Handle(GetUsersQuery q, CancellationToken ct)
    {
        var pageSize = Math.Min(q.PageSize, MaxPageSize);

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
            .Skip((q.PageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        // Batch role loading — one query per role (we have 2 roles: "desktop", "mobile")
        // instead of one query per user. Eliminates the N+1 pattern where calling
        // GetRolesAsync in a loop issued 20+ queries per page (professor's issue #17).
        var allRoles = new[] { "desktop", "mobile" };
        var roleMap = new Dictionary<Guid, List<string>>();

        foreach (var roleName in allRoles)
        {
            var usersInRole = await userManager.GetUsersInRoleAsync(roleName);
            var inRoleIds = usersInRole.Select(u => u.Id).ToHashSet();
            foreach (var user in users.Where(u => inRoleIds.Contains(u.Id)))
            {
                if (!roleMap.TryGetValue(user.Id, out var list))
                    roleMap[user.Id] = list = [];
                list.Add(roleName);
            }
        }

        var dtos = users.Select(u => new UserDto(
            u.Id, u.UserName!, u.Email!, u.FirstName, u.LastName,
            u.ProfilePhotoUrl, u.IsBlocked, u.CreatedAt,
            roleMap.TryGetValue(u.Id, out var roles) ? roles : []));

        return new PagedList<UserDto>(dtos, totalCount, q.PageNumber, pageSize);
    }
}
