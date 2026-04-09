using MediatR;
using Microsoft.Extensions.Logging;

namespace Inkril.Application.Common.Behaviors;

public class LoggingBehavior<TRequest, TResponse>(ILogger<LoggingBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken ct)
    {
        var requestName = typeof(TRequest).Name;
        logger.LogInformation("Handling {RequestName}", requestName);

        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        var response = await next();
        stopwatch.Stop();

        if (stopwatch.ElapsedMilliseconds > 500)
            logger.LogWarning("Slow request: {RequestName} took {Elapsed}ms", requestName, stopwatch.ElapsedMilliseconds);
        else
            logger.LogInformation("Handled {RequestName} in {Elapsed}ms", requestName, stopwatch.ElapsedMilliseconds);

        return response;
    }
}
