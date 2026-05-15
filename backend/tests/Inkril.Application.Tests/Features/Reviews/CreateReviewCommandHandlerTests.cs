using FluentAssertions;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Features.Reviews.Commands;
using Inkril.Domain.Entities;
using MockQueryable.Moq;
using Moq;

namespace Inkril.Application.Tests.Features.Reviews;

/// <summary>
/// Regression tests for CreateReviewCommandHandler.
///
/// Critical invariants:
///   1. Ownership gate — non-owners are blocked.
///   2. Duplicate gate — a user cannot submit two reviews for the same book.
///   3. Average rating is recalculated correctly using the DB aggregation path.
///
/// Note on MockQueryable: the handler calls
///     uow.Reviews.Query().Where(...).SumAsync(r => r.Rating, ct)
/// SumAsync is an EF Core async extension that requires IAsyncQueryProvider.
/// MockQueryable.Moq's BuildMock() wraps a List<T> into an IQueryable<T> that
/// satisfies this requirement — without it, SumAsync would throw at runtime.
/// </summary>
public class CreateReviewCommandHandlerTests
{
    // ── Fixture helpers ───────────────────────────────────────────────────────

    private static (Mock<IUnitOfWork> uow,
                    Mock<IRepository<Book>> bookRepo,
                    Mock<IRepository<UserBook>> ubRepo,
                    Mock<IRepository<Review>> reviewRepo) BuildMocks(
        Book? book = null,
        bool ownsBook = true,
        bool alreadyReviewed = false,
        List<Review>? existingReviews = null)
    {
        var uow        = new Mock<IUnitOfWork>();
        var bookRepo   = new Mock<IRepository<Book>>();
        var ubRepo     = new Mock<IRepository<UserBook>>();
        var reviewRepo = new Mock<IRepository<Review>>();

        uow.Setup(u => u.Books).Returns(bookRepo.Object);
        uow.Setup(u => u.UserBooks).Returns(ubRepo.Object);
        uow.Setup(u => u.Reviews).Returns(reviewRepo.Object);

        bookRepo.Setup(r => r.GetByIdAsync(It.IsAny<Guid>(), default))
                .ReturnsAsync(book);

        ubRepo.Setup(r => r.AnyAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<UserBook, bool>>>(), default))
            .ReturnsAsync(ownsBook);

        reviewRepo.Setup(r => r.AnyAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<Review, bool>>>(), default))
            .ReturnsAsync(alreadyReviewed);

        // CountAsync is defined directly on IRepository<T> — no MockQueryable needed.
        var reviews = existingReviews ?? [];
        reviewRepo.Setup(r => r.CountAsync(
            It.IsAny<System.Linq.Expressions.Expression<Func<Review, bool>>>(), default))
            .ReturnsAsync(reviews.Count);

        // Query().Where(...).SumAsync(...) requires IAsyncQueryProvider — use BuildMock().
        var queryable = reviews.AsQueryable().BuildMock();
        reviewRepo.Setup(r => r.Query()).Returns(queryable);

        reviewRepo.Setup(r => r.AddAsync(It.IsAny<Review>(), default)).Returns(Task.CompletedTask);
        bookRepo.Setup(r => r.Update(It.IsAny<Book>())); // void — no return needed

        return (uow, bookRepo, ubRepo, reviewRepo);
    }

    private static Book SomeBook(Guid? id = null) => new()
    {
        Id          = id ?? Guid.NewGuid(),
        Title       = "Test Book",
        AverageRating = 0,
        RatingCount = 0,
    };

    // ── Ownership gate regression ─────────────────────────────────────────────

    [Fact]
    public async Task Handle_UserDoesNotOwnBook_ReturnsFailure()
    {
        var bookId   = Guid.NewGuid();
        var book     = SomeBook(bookId);
        var (uow, _, _, _) = BuildMocks(book: book, ownsBook: false);

        var handler = new CreateReviewCommandHandler(uow.Object);
        var result  = await handler.Handle(
            new CreateReviewCommand(Guid.NewGuid(), bookId, 4, "Great!"), default);

        result.Succeeded.Should().BeFalse();
        result.Errors[0].Should().Contain("library");
    }

    // ── Duplicate review gate ─────────────────────────────────────────────────

    [Fact]
    public async Task Handle_UserAlreadyReviewed_ReturnsFailure()
    {
        var bookId = Guid.NewGuid();
        var book   = SomeBook(bookId);
        var (uow, _, _, _) = BuildMocks(book: book, ownsBook: true, alreadyReviewed: true);

        var handler = new CreateReviewCommandHandler(uow.Object);
        var result  = await handler.Handle(
            new CreateReviewCommand(Guid.NewGuid(), bookId, 3, null), default);

        result.Succeeded.Should().BeFalse();
        result.Errors[0].Should().Contain("already reviewed");
    }

    // ── Average rating recalculation ──────────────────────────────────────────

    [Fact]
    public async Task Handle_FirstReview_SetsAverageToRating()
    {
        var bookId = Guid.NewGuid();
        var book   = SomeBook(bookId);

        // No existing reviews — this is the first one.
        var (uow, bookRepo, _, _) = BuildMocks(
            book: book,
            ownsBook: true,
            alreadyReviewed: false,
            existingReviews: []);

        Book? updatedBook = null;
        bookRepo.Setup(r => r.Update(It.IsAny<Book>()))
                .Callback<Book>(b => updatedBook = b);

        var handler = new CreateReviewCommandHandler(uow.Object);
        var result  = await handler.Handle(
            new CreateReviewCommand(Guid.NewGuid(), bookId, 5, "Loved it"), default);

        result.Succeeded.Should().BeTrue();
        // existingSum = 0, existingCount = 0 → newAvg = (0+5)/1 = 5.0
        updatedBook!.AverageRating.Should().Be(5.0);
        updatedBook.RatingCount.Should().Be(1);
    }

    [Fact]
    public async Task Handle_SecondReview_AveragesCorrectly()
    {
        var bookId = Guid.NewGuid();
        var book   = SomeBook(bookId);

        // One existing review with rating 4 for the same book.
        var userId = Guid.NewGuid();
        var existingReviews = new List<Review>
        {
            new() { UserId = userId, BookId = bookId, Rating = 4 }
        };

        var (uow, bookRepo, _, _) = BuildMocks(
            book: book,
            ownsBook: true,
            alreadyReviewed: false,
            existingReviews: existingReviews);

        Book? updatedBook = null;
        bookRepo.Setup(r => r.Update(It.IsAny<Book>()))
                .Callback<Book>(b => updatedBook = b);

        var handler = new CreateReviewCommandHandler(uow.Object);
        var result  = await handler.Handle(
            new CreateReviewCommand(Guid.NewGuid(), bookId, 2, "Not great"), default);

        result.Succeeded.Should().BeTrue();
        // existingSum = 4, existingCount = 1 → newAvg = (4+2)/2 = 3.0
        updatedBook!.AverageRating.Should().Be(3.0);
        updatedBook.RatingCount.Should().Be(2);
    }
}
