using FluentValidation;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace Inkril.Application.Features.Auth.Commands;

public record LoginCommand(string UserNameOrEmail, string Password) : IRequest<Result<AuthResponse>>;

public class LoginCommandValidator : AbstractValidator<LoginCommand>
{
    public LoginCommandValidator()
    {
        RuleFor(x => x.UserNameOrEmail).NotEmpty();
        RuleFor(x => x.Password).NotEmpty();
    }
}

public class LoginCommandHandler(
    UserManager<ApplicationUser> userManager,
    ITokenService tokenService
) : IRequestHandler<LoginCommand, Result<AuthResponse>>
{
    public async Task<Result<AuthResponse>> Handle(LoginCommand cmd, CancellationToken ct)
    {
        var user = await userManager.FindByEmailAsync(cmd.UserNameOrEmail)
                   ?? await userManager.FindByNameAsync(cmd.UserNameOrEmail);

        if (user is null || user.IsDeleted || user.IsBlocked)
            return Result<AuthResponse>.Failure("Invalid credentials or account is inactive.");

        if (!await userManager.CheckPasswordAsync(user, cmd.Password))
            return Result<AuthResponse>.Failure("Invalid credentials.");

        var (access, refresh) = await tokenService.GenerateTokensAsync(user);
        return Result<AuthResponse>.Success(new AuthResponse(access, refresh, user.Id, user.UserName!, user.Email!));
    }
}
