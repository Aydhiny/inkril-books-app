using Inkril.Application.Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace Inkril.API.Controllers;

/// <summary>
/// Base controller that maps Result / Result&lt;T&gt; to RFC 7807 ProblemDetails responses,
/// eliminating the BadRequest(new { errors }) pattern across all controllers.
/// </summary>
[ApiController]
public abstract class ApiControllerBase : ControllerBase
{
    /// <summary>Maps a typed result — calls onSuccess on success, ValidationProblem on failure.</summary>
    protected IActionResult ToResult<T>(Result<T> result, Func<T, IActionResult> onSuccess)
        => result.Succeeded
            ? onSuccess(result.Value!)
            : ValidationProblem(new ValidationProblemDetails
              {
                  Detail = string.Join("; ", result.Errors)
              });

    /// <summary>Maps a non-typed result — returns onSuccess on success, ValidationProblem on failure.</summary>
    protected IActionResult ToResult(Result result, IActionResult onSuccess)
        => result.Succeeded
            ? onSuccess
            : ValidationProblem(new ValidationProblemDetails
              {
                  Detail = string.Join("; ", result.Errors)
              });
}
