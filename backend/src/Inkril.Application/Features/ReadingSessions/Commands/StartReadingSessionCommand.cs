using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;

namespace Inkril.Application.Features.ReadingSessions.Commands;

public record StartReadingSessionCommand(Guid BookId, int StartPage) : IRequest<Result<Guid>>;

public class StartReadingSessionCommandValidator : AbstractValidator<StartReadingSessionCommand>
{
    public StartReadingSessionCommandValidator()
    {
        RuleFor(x => x.BookId).NotEmpty();
        RuleFor(x => x.StartPage).GreaterThanOrEqualTo(0);
    }
}

public class StartReadingSessionCommandHandler(IUnitOfWork uow, ICurrentUserService currentUser)
    : IRequestHandler<StartReadingSessionCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(StartReadingSessionCommand cmd, CancellationToken ct)
    {
        var userId = currentUser.UserId ?? throw new UnauthorizedAccessException();

        var book = await uow.Books.GetByIdAsync(cmd.BookId, ct);
        if (book is null) return Result<Guid>.Failure("Book not found.");

        var ownsBook = await uow.UserBooks.AnyAsync(
            ub => ub.UserId == userId && ub.BookId == cmd.BookId, ct);
        if (!ownsBook)
            return Result<Guid>.Failure("You can only start reading sessions for books in your library.");

        var session = new ReadingSession
        {
            UserId = userId,
            BookId = cmd.BookId,
            StartPage = cmd.StartPage,
            StartedAt = DateTime.UtcNow,
            CreatedBy = userId.ToString()
        };

        await uow.ReadingSessions.AddAsync(session, ct);
        await uow.SaveChangesAsync(ct);

        return Result<Guid>.Success(session.Id);
    }
}
