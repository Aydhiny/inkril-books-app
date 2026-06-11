using Inkril.Application.Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

/// <summary>
/// Base controller that maps Result / Result&lt;T&gt; to the correct HTTP status code,
/// eliminating the BadRequest(new { errors }) pattern across all controllers.
/// </summary>
[ApiController]
public abstract class ApiControllerBase : ControllerBase
{
    /// <summary>Maps a typed result — calls onSuccess on success, error response on failure.</summary>
    protected IActionResult ToResult<T>(Result<T> result, Func<T, IActionResult> onSuccess)
        => result.Succeeded ? onSuccess(result.Value!) : FailureResult(result);

    /// <summary>Maps a non-typed result — returns onSuccess on success, error response on failure.</summary>
    protected IActionResult ToResult(Result result, IActionResult onSuccess)
        => result.Succeeded ? onSuccess : FailureResult(result);

    private IActionResult FailureResult(Result result)
    {
        var detail = string.Join("; ", result.Errors);
        return result.ErrorType switch
        {
            ResultErrorType.NotFound     => NotFound(new ProblemDetails { Detail = detail }),
            ResultErrorType.Forbidden    => StatusCode(403, new ProblemDetails { Detail = detail }),
            ResultErrorType.Conflict     => Conflict(new ProblemDetails { Detail = detail }),
            ResultErrorType.Unauthorized => Unauthorized(new ProblemDetails { Detail = detail }),
            _                            => ValidationProblem(new ValidationProblemDetails { Detail = detail })
        };
    }
}
