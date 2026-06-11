namespace Inkril.Application.Common.Models;

public enum ResultErrorType { Validation, NotFound, Forbidden, Conflict, Unauthorized }

/// <summary>
/// Railway-oriented result type — avoids exception-driven control flow for
/// expected error cases (validation failures, not found, etc.).
/// </summary>
public class Result
{
    protected Result(bool succeeded, IEnumerable<string> errors,
        ResultErrorType errorType = ResultErrorType.Validation)
    {
        Succeeded = succeeded;
        Errors    = errors.ToArray();
        ErrorType = errorType;
    }

    public bool            Succeeded { get; }
    public string[]        Errors    { get; }
    public ResultErrorType ErrorType { get; }

    public static Result Success()    => new(true, []);
    public static Result Failure(params string[] errors)    => new(false, errors);
    public static Result NotFound(params string[] errors)   => new(false, errors, ResultErrorType.NotFound);
    public static Result Forbidden(params string[] errors)  => new(false, errors, ResultErrorType.Forbidden);
    public static Result Conflict(params string[] errors)   => new(false, errors, ResultErrorType.Conflict);
    public static Result Unauthorized(params string[] errors) => new(false, errors, ResultErrorType.Unauthorized);
}

public class Result<T> : Result
{
    private Result(bool succeeded, T? value, IEnumerable<string> errors,
        ResultErrorType errorType = ResultErrorType.Validation)
        : base(succeeded, errors, errorType)
    {
        Value = value;
    }

    public T? Value { get; }

    public static Result<T> Success(T value) => new(true, value, []);
    public static new Result<T> Failure(params string[] errors)      => new(false, default, errors);
    public static new Result<T> NotFound(params string[] errors)     => new(false, default, errors, ResultErrorType.NotFound);
    public static new Result<T> Forbidden(params string[] errors)    => new(false, default, errors, ResultErrorType.Forbidden);
    public static new Result<T> Conflict(params string[] errors)     => new(false, default, errors, ResultErrorType.Conflict);
    public static new Result<T> Unauthorized(params string[] errors) => new(false, default, errors, ResultErrorType.Unauthorized);
}
