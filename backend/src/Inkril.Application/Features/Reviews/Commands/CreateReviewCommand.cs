using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Inkril.Application.Features.Reviews.Commands;

public record CreateReviewCommand(Guid UserId, Guid BookId, int Rating, string? Comment) : IRequest<Result<Guid>>;

public class CreateReviewCommandValidator : AbstractValidator<CreateReviewCommand>
{
    public CreateReviewCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.BookId).NotEmpty();
        RuleFor(x => x.Rating).InclusiveBetween(1, 5)
            .WithMessage("Rating must be between 1 and 5.");
        RuleFor(x => x.Comment).MaximumLength(2000).When(x => x.Comment != null);
    }
}

public class CreateReviewCommandHandler(IUnitOfWork uow)
    : IRequestHandler<CreateReviewCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateReviewCommand cmd, CancellationToken ct)
    {
        var book = await uow.Books.GetByIdAsync(cmd.BookId, ct);
        if (book is null) return Result<Guid>.Failure("Book not found.");

        var alreadyReviewed = await uow.Reviews.AnyAsync(
            r => r.UserId == cmd.UserId && r.BookId == cmd.BookId, ct);
        if (alreadyReviewed)
            return Result<Guid>.Failure("You have already reviewed this book.");

        var review = new Review
        {
            UserId = cmd.UserId,
            BookId = cmd.BookId,
            Rating = cmd.Rating,
            Comment = cmd.Comment,
            CreatedBy = cmd.UserId.ToString()
        };

        await uow.Reviews.AddAsync(review, ct);

        var allReviews = await uow.Reviews.FindAsync(r => r.BookId == cmd.BookId, ct);
        var ratings = allReviews.Select(r => r.Rating).Append(cmd.Rating).ToList();
        book.AverageRating = Math.Round(ratings.Average(), 2);
        book.RatingCount = ratings.Count;
        book.UpdatedAt = DateTime.UtcNow;
        uow.Books.Update(book);

        await uow.SaveChangesAsync(ct);

        return Result<Guid>.Success(review.Id);
    }
}
