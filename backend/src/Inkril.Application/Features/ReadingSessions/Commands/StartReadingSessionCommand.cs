using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;

namespace Inkril.Application.Features.ReadingSessions.Commands;

public record StartReadingSessionCommand(Guid UserId, Guid BookId, int StartPage) : IRequest<Result<Guid>>;

public class StartReadingSessionCommandValidator : AbstractValidator<StartReadingSessionCommand>
{
    public StartReadingSessionCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.BookId).NotEmpty();
        RuleFor(x => x.StartPage).GreaterThanOrEqualTo(0);
    }
}

public class StartReadingSessionCommandHandler(IUnitOfWork uow)
    : IRequestHandler<StartReadingSessionCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(StartReadingSessionCommand cmd, CancellationToken ct)
    {
        var book = await uow.Books.GetByIdAsync(cmd.BookId, ct);
        if (book is null) return Result<Guid>.Failure("Book not found.");

        // Ownership check — only users who have the book in their library may log reading
        // sessions. Without this, any user could inflate reading-time signals for any book,
        // corrupting the content-based recommendation engine (same class as review fix).
        var ownsBook = await uow.UserBooks.AnyAsync(
            ub => ub.UserId == cmd.UserId && ub.BookId == cmd.BookId, ct);
        if (!ownsBook)
            return Result<Guid>.Failure("You can only start reading sessions for books in your library.");

        var session = new ReadingSession
        {
            UserId = cmd.UserId,
            BookId = cmd.BookId,
            StartPage = cmd.StartPage,
            StartedAt = DateTime.UtcNow,
            CreatedBy = cmd.UserId.ToString()
        };

        await uow.ReadingSessions.AddAsync(session, ct);
        await uow.SaveChangesAsync(ct);

        return Result<Guid>.Success(session.Id);
    }
}
