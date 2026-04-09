namespace Inkril.Domain.Common;

/// <summary>
/// Base class for all domain entities.
/// Provides audit fields required by the professor's non-functional requirements.
/// Soft-delete is handled via IsDeleted so records are never physically removed.
/// </summary>
public abstract class BaseEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }

    public bool IsDeleted { get; set; } = false;

    public string? CreatedBy { get; set; }

    public string? UpdatedBy { get; set; }
}
