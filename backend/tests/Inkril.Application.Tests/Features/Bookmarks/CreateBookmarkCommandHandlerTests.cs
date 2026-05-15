using FluentAssertions;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Bookmarks.Commands;
using Inkril.Domain.Entities;
using Moq;

namespace Inkril.Application.Tests.Features.Bookmarks;

/// <summary>
/// Regression tests for CreateBookmarkCommandHandler.
///
/// Critical invariants:
///   1. Users may only bookmark books they own — ownership gate must block non-owners.
///   2. Default color is #FFD700 when no color is supplied.
/// </summary>
public class CreateBookmarkCommandHandlerTests
{
    // ── Fixture helpers ───────────────────────────────────────────────────────

    private static (Mock<IUnitOfWork> uow, Mock<IRepository<Book>> bookRepo,
                    Mock<IRepository<UserBook>> userBookRepo,
                    Mock<IRepository<Bookmark>> bookmarkRepo) BuildMocks()
    {
        var uow          = new Mock<IUnitOfWork>();
        var bookRepo     = new Mock<IRepository<Book>>();
        var userBookRepo = new Mock<IRepository<UserBook>>();
        var bookmarkRepo = new Mock<IRepository<Bookmark>>();

        uow.Setup(u => u.Books).Returns(bookRepo.Object);
        uow.Setup(u => u.UserBooks).Returns(userBookRepo.Object);
        uow.Setup(u => u.Bookmarks).Returns(bookmarkRepo.Object);

        return (uow, bookRepo, userBookRepo, bookmarkRepo);
    }

    private static Book SomeBook(Guid? id = null) => new()
    {
        Id    = id ?? Guid.NewGuid(),
        Title = "Test Book",
    };

    // ── Ownership gate regression ─────────────────────────────────────────────

    [Fact]
    public async Task Handle_UserDoesNotOwnBook_ReturnsFailure()
    {
        var (uow, bookRepo, userBookRepo, _) = BuildMocks();
        var bookId = Guid.NewGuid();

        bookRepo.Setup(r => r.GetByIdAsync(bookId, default)).ReturnsAsync(SomeBook(bookId));
        // User does NOT own this book
        userBookRepo.Setup(r => r.AnyAsync(It.IsAny<System.Linq.Expressions.Expression<Func<UserBook, bool>>>(), default))
                    .ReturnsAsync(false);

        var handler = new CreateBookmarkCommandHandler(uow.Object);
        var result  = await handler.Handle(
            new CreateBookmarkCommand(Guid.NewGuid(), bookId, 1, null, null, null), default);

        result.Succeeded.Should().BeFalse();
        result.Errors[0].Should().Contain("library");
    }

    [Fact]
    public async Task Handle_BookNotFound_ReturnsFailure()
    {
        var (uow, bookRepo, _, _) = BuildMocks();
        var bookId = Guid.NewGuid();

        bookRepo.Setup(r => r.GetByIdAsync(bookId, default)).ReturnsAsync((Book?)null);

        var handler = new CreateBookmarkCommandHandler(uow.Object);
        var result  = await handler.Handle(
            new CreateBookmarkCommand(Guid.NewGuid(), bookId, 5, null, null, null), default);

        result.Succeeded.Should().BeFalse();
        result.Errors[0].Should().Contain("not found");
    }

    // ── Default color ─────────────────────────────────────────────────────────

    [Fact]
    public async Task Handle_NoColorSupplied_DefaultsToGold()
    {
        var (uow, bookRepo, userBookRepo, bookmarkRepo) = BuildMocks();
        var bookId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        bookRepo.Setup(r => r.GetByIdAsync(bookId, default)).ReturnsAsync(SomeBook(bookId));
        userBookRepo.Setup(r => r.AnyAsync(It.IsAny<System.Linq.Expressions.Expression<Func<UserBook, bool>>>(), default))
                    .ReturnsAsync(true);

        Bookmark? captured = null;
        bookmarkRepo.Setup(r => r.AddAsync(It.IsAny<Bookmark>(), default))
                    .Callback<Bookmark, CancellationToken>((b, _) => captured = b)
                    .Returns(Task.CompletedTask);

        var handler = new CreateBookmarkCommandHandler(uow.Object);
        var result  = await handler.Handle(
            new CreateBookmarkCommand(userId, bookId, 3, null, null, null), default);

        result.Succeeded.Should().BeTrue();
        captured!.Color.Should().Be("#FFD700");
    }

    // ── Success path ──────────────────────────────────────────────────────────

    [Fact]
    public async Task Handle_ValidOwner_ReturnsBookmarkId()
    {
        var (uow, bookRepo, userBookRepo, bookmarkRepo) = BuildMocks();
        var bookId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        bookRepo.Setup(r => r.GetByIdAsync(bookId, default)).ReturnsAsync(SomeBook(bookId));
        userBookRepo.Setup(r => r.AnyAsync(It.IsAny<System.Linq.Expressions.Expression<Func<UserBook, bool>>>(), default))
                    .ReturnsAsync(true);
        bookmarkRepo.Setup(r => r.AddAsync(It.IsAny<Bookmark>(), default)).Returns(Task.CompletedTask);

        var handler = new CreateBookmarkCommandHandler(uow.Object);
        var result  = await handler.Handle(
            new CreateBookmarkCommand(userId, bookId, 10, "some text", "my note", "#FF0000"), default);

        result.Succeeded.Should().BeTrue();
        result.Value.Should().NotBe(Guid.Empty);
    }
}
