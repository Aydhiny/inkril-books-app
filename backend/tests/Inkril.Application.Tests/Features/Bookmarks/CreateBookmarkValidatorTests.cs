using FluentAssertions;
using FluentValidation.TestHelper;
using Inkril.Application.Features.Bookmarks.Commands;

namespace Inkril.Application.Tests.Features.Bookmarks;

/// <summary>
/// Unit tests for CreateBookmarkCommandValidator.
/// Validators are pure functions with no external dependencies — no mocks needed.
/// </summary>
public class CreateBookmarkValidatorTests
{
    private readonly CreateBookmarkCommandValidator _validator = new();

    [Fact]
    public void Validate_PageNumberZero_Fails()
    {
        var cmd = new CreateBookmarkCommand(
            Guid.NewGuid(), Guid.NewGuid(), PageNumber: 0,
            HighlightedText: null, Note: null, Color: null);

        var result = _validator.TestValidate(cmd);

        result.ShouldHaveValidationErrorFor(x => x.PageNumber)
              .WithErrorMessage("Page number must be greater than 0.");
    }

    [Fact]
    public void Validate_PageNumberNegative_Fails()
    {
        var cmd = new CreateBookmarkCommand(
            Guid.NewGuid(), Guid.NewGuid(), PageNumber: -5,
            HighlightedText: null, Note: null, Color: null);

        var result = _validator.TestValidate(cmd);

        result.ShouldHaveValidationErrorFor(x => x.PageNumber);
    }

    [Fact]
    public void Validate_HighlightedTextTooLong_Fails()
    {
        var cmd = new CreateBookmarkCommand(
            Guid.NewGuid(), Guid.NewGuid(), PageNumber: 1,
            HighlightedText: new string('x', 2001), Note: null, Color: null);

        var result = _validator.TestValidate(cmd);

        result.ShouldHaveValidationErrorFor(x => x.HighlightedText);
    }

    [Fact]
    public void Validate_ValidCommand_Passes()
    {
        var cmd = new CreateBookmarkCommand(
            Guid.NewGuid(), Guid.NewGuid(), PageNumber: 42,
            HighlightedText: "a quote", Note: "great line", Color: "#FF0000");

        var result = _validator.TestValidate(cmd);

        result.ShouldNotHaveAnyValidationErrors();
    }
}
