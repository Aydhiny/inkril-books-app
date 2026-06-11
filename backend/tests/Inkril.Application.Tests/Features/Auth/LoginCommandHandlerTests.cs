using FluentAssertions;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Auth.Commands;
using Inkril.Domain.Entities;
using Microsoft.AspNetCore.Identity;
using Moq;

namespace Inkril.Application.Tests.Features.Auth;

/// <summary>
/// Regression tests for LoginCommandHandler.
///
/// Critical invariant: every failure path — non-existent account, soft-deleted
/// account, blocked account, wrong password — must return the SAME error message.
/// Differentiated messages are a user-enumeration oracle attack vector.
/// </summary>
public class LoginCommandHandlerTests
{
    // ── Fixture helpers ───────────────────────────────────────────────────────

    private static Mock<UserManager<ApplicationUser>> BuildUserManagerMock()
    {
        // UserManager has no default constructor — its primary ctor requires an
        // IUserStore plus 8 optional services (all nullable in tests).
        var store = new Mock<IUserStore<ApplicationUser>>();
#pragma warning disable CS8625 // null literals for optional UserManager ctor params
        return new Mock<UserManager<ApplicationUser>>(
            store.Object, null, null, null, null, null, null, null, null);
#pragma warning restore CS8625
    }

    private static ApplicationUser ActiveUser(string userName = "alice") => new()
    {
        Id        = Guid.NewGuid(),
        UserName  = userName,
        Email     = $"{userName}@example.com",
        IsDeleted = false,
        IsBlocked = false,
    };

    // ── Oracle-attack regression tests ───────────────────────────────────────

    [Fact]
    public async Task Handle_UserNotFound_ReturnsIdenticalMessage()
    {
        var um     = BuildUserManagerMock();
        var tokens = new Mock<ITokenService>();

        um.Setup(m => m.FindByEmailAsync(It.IsAny<string>())).ReturnsAsync((ApplicationUser?)null);
        um.Setup(m => m.FindByNameAsync(It.IsAny<string>())).ReturnsAsync((ApplicationUser?)null);

        var handler = new LoginCommandHandler(um.Object, tokens.Object);
        var result  = await handler.Handle(new LoginCommand("nobody@example.com", "pass"), default);

        result.Succeeded.Should().BeFalse();
        result.Errors[0].Should().Be("Invalid credentials.");
    }

    [Fact]
    public async Task Handle_DeletedUser_ReturnsSameMessageAsNotFound()
    {
        var um     = BuildUserManagerMock();
        var tokens = new Mock<ITokenService>();
        var user   = ActiveUser();
        user.IsDeleted = true;

        um.Setup(m => m.FindByEmailAsync(It.IsAny<string>())).ReturnsAsync(user);

        var handler  = new LoginCommandHandler(um.Object, tokens.Object);
        var result   = await handler.Handle(new LoginCommand(user.Email!, "pass"), default);

        result.Succeeded.Should().BeFalse();
        // Message must be identical to the "not found" case — no oracle leakage.
        result.Errors[0].Should().Be("Invalid credentials.");
    }

    [Fact]
    public async Task Handle_BlockedUser_ReturnsSameMessageAsNotFound()
    {
        var um     = BuildUserManagerMock();
        var tokens = new Mock<ITokenService>();
        var user   = ActiveUser();
        user.IsBlocked = true;

        um.Setup(m => m.FindByEmailAsync(It.IsAny<string>())).ReturnsAsync(user);

        var handler = new LoginCommandHandler(um.Object, tokens.Object);
        var result  = await handler.Handle(new LoginCommand(user.Email!, "pass"), default);

        result.Succeeded.Should().BeFalse();
        result.Errors[0].Should().Be("Invalid credentials.");
    }

    [Fact]
    public async Task Handle_WrongPassword_ReturnsSameMessageAsNotFound()
    {
        var um     = BuildUserManagerMock();
        var tokens = new Mock<ITokenService>();
        var user   = ActiveUser();

        um.Setup(m => m.FindByEmailAsync(user.Email!)).ReturnsAsync(user);
        // CheckPasswordAsync returns false → wrong password
        um.Setup(m => m.CheckPasswordAsync(user, It.IsAny<string>())).ReturnsAsync(false);

        var handler = new LoginCommandHandler(um.Object, tokens.Object);
        var result  = await handler.Handle(new LoginCommand(user.Email!, "wrongpass"), default);

        result.Succeeded.Should().BeFalse();
        result.Errors[0].Should().Be("Invalid credentials.");
    }

    // ── Success path ─────────────────────────────────────────────────────────

    [Fact]
    public async Task Handle_ValidCredentials_ReturnsTokens()
    {
        var um     = BuildUserManagerMock();
        var tokens = new Mock<ITokenService>();
        var user   = ActiveUser();

        um.Setup(m => m.FindByEmailAsync(user.Email!)).ReturnsAsync(user);
        um.Setup(m => m.CheckPasswordAsync(user, "correct")).ReturnsAsync(true);
        tokens.Setup(t => t.GenerateTokensAsync(user))
              .ReturnsAsync(("access-token", "refresh-token"));

        var handler = new LoginCommandHandler(um.Object, tokens.Object);
        var result  = await handler.Handle(new LoginCommand(user.Email!, "correct"), default);

        result.Succeeded.Should().BeTrue();
        result.Value!.AccessToken.Should().Be("access-token");
        result.Value.RefreshToken.Should().Be("refresh-token");
    }
}
