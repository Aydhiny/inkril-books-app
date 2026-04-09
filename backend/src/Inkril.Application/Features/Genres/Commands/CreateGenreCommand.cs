using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using Inkril.Domain.Entities;
using MediatR;

namespace Inkril.Application.Features.Genres.Commands;

public record CreateGenreCommand(string Name, string? Description) : IRequest<Result<Guid>>;

public class CreateGenreCommandValidator : AbstractValidator<CreateGenreCommand>
{
    public CreateGenreCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
    }
}

public class CreateGenreCommandHandler(IUnitOfWork uow)
    : IRequestHandler<CreateGenreCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateGenreCommand cmd, CancellationToken ct)
    {
        var exists = await uow.Genres.AnyAsync(g => g.Name == cmd.Name, ct);
        if (exists)
            return Result<Guid>.Failure($"A genre named '{cmd.Name}' already exists.");

        var genre = new Genre { Name = cmd.Name, Description = cmd.Description };
        await uow.Genres.AddAsync(genre, ct);
        await uow.SaveChangesAsync(ct);

        return Result<Guid>.Success(genre.Id);
    }
}
