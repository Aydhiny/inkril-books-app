using FluentAssertions;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.ReadingSessions.Commands;
using Inkril.Domain.Entities;
using Moq;

namespace Inkril.Application.Tests.Features.ReadingSessions;

/// <summary>
/// Regression tests for StartReadingSessionCommandHandler.
///
/// Critical invariant: only users who own a book may log reading sessions for it.
/// Without this gate, any user could inflate reading-time signals for any book,
/// corrupting the content-based recommendation engine.
/// </summary>
public class StartReadingSessionCommandHandlerTests
{
    private static (Mock<IUnitOfWork> uow, Mock<IRepository<Book>> bookRepo,
                    Mock<IRepository<UserBook>> userBookRepo,
                    Mock<IRepository<ReadingSession>> sessionRepo,
                    Mock<ICurrentUserService> currentUser) BuildMocks(Guid userId)
    {
        var uow         = new Mock<IUnitOfWork>();
        var bookRepo    = new Mock<IRepository<Book>>();
        var ubRepo      = new Mock<IRepository<UserBook>>();
        var sessionRepo = new Mock<IRepository<ReadingSession>>();
        var currentUser = new Mock<ICurrentUserService>();

        currentUser.Setup(c => c.UserId).Returns(userId);

        uow.Setup(u => u.Books).Returns(bookRepo.Object);
        uow.Setup(u => u.UserBooks).Returns(ubRepo.Object);
        uow.Setup(u => u.ReadingSessions).Returns(sessionRepo.Object);

        return (uow, bookRepo, ubRepo, sessionRepo, currentUser);
    }

    // ── Ownership gate regression ─────────────────────────────────────────────

    [Fact]
    public async Task Handle_UserDoesNotOwnBook_ReturnsFailure()
    {
        var userId = Guid.NewGuid();
        var (uow, bookRepo, userBookRepo, _, currentUser) = BuildMocks(userId);
        var bookId = Guid.NewGuid();

        bookRepo.Setup(r => r.GetByIdAsync(bookId, default))
                .ReturnsAsync(new Book { Id = bookId, Title = "Book" });

        userBookRepo.Setup(r => r.AnyAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<UserBook, bool>>>(), default))
            .ReturnsAsync(false);

        var handler = new StartReadingSessionCommandHandler(uow.Object, currentUser.Object);
        var result  = await handler.Handle(
            new StartReadingSessionCommand(bookId, 0), default);

        result.Succeeded.Should().BeFalse();
        result.Errors[0].Should().Contain("library");
    }

    // ── Success path ──────────────────────────────────────────────────────────

    [Fact]
    public async Task Handle_OwnerStartsSession_ReturnsSessionId()
    {
        var userId = Guid.NewGuid();
        var (uow, bookRepo, userBookRepo, sessionRepo, currentUser) = BuildMocks(userId);
        var bookId = Guid.NewGuid();

        bookRepo.Setup(r => r.GetByIdAsync(bookId, default))
                .ReturnsAsync(new Book { Id = bookId, Title = "Book" });

        userBookRepo.Setup(r => r.AnyAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<UserBook, bool>>>(), default))
            .ReturnsAsync(true);

        sessionRepo.Setup(r => r.AddAsync(It.IsAny<ReadingSession>(), default))
                   .Returns(Task.CompletedTask);

        var handler = new StartReadingSessionCommandHandler(uow.Object, currentUser.Object);
        var result  = await handler.Handle(
            new StartReadingSessionCommand(bookId, 1), default);

        result.Succeeded.Should().BeTrue();
        result.Value.Should().NotBe(Guid.Empty);
    }
}
