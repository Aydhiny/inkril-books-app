namespace Inkril.Domain.Entities;

/// <summary>
/// Many-to-many join between Book and Genre.
/// Has no extra attributes so counts as a reference/join table.
/// </summary>
public class BookGenre
{
    public Guid BookId { get; set; }
    public Book Book { get; set; } = null!;

    public Guid GenreId { get; set; }
    public Genre Genre { get; set; } = null!;
}
