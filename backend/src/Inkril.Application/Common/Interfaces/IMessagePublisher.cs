namespace Inkril.Application.Common.Interfaces;

/// <summary>
/// Abstraction for publishing messages to RabbitMQ.
/// Implemented in Infrastructure so Application stays framework-agnostic.
/// The NotificationWorker (separate microservice) consumes these messages.
/// </summary>
public interface IMessagePublisher
{
    Task PublishAsync<T>(T message, string routingKey, CancellationToken ct = default) where T : class;
}
