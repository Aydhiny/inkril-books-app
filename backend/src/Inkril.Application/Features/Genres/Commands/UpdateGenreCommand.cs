using FluentValidation;
using Inkril.Application.Common.Interfaces;
using Inkril.Application.Common.Models;
using MediatR;

namespace Inkril.Application.Features.Genres.Commands;

public record UpdateGenreCommand(Guid Id, string Name, string? Description) : IRequest<Result>;

public class UpdateGenreCommandValidator : AbstractValidator<UpdateGenreCommand>
{
    public UpdateGenreCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
    }
}

public class UpdateGenreCommandHandler(IUnitOfWork uow)
    : IRequestHandler<UpdateGenreCommand, Result>
{
    public async Task<Result> Handle(UpdateGenreCommand cmd, CancellationToken ct)
    {
        var genre = await uow.Genres.GetByIdAsync(cmd.Id, ct);
        if (genre is null)
            return Result.Failure("Genre not found.");

        var nameConflict = await uow.Genres.AnyAsync(
            g => g.Name == cmd.Name && g.Id != cmd.Id, ct);
        if (nameConflict)
            return Result.Failure($"A genre named '{cmd.Name}' already exists.");

        genre.Name = cmd.Name;
        genre.Description = cmd.Description;
        genre.UpdatedAt = DateTime.UtcNow;

        uow.Genres.Update(genre);
        await uow.SaveChangesAsync(ct);

        return Result.Success();
    }
}
