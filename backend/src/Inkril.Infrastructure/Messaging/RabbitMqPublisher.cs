using System.Text;
using Inkril.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using RabbitMQ.Client;

namespace Inkril.Infrastructure.Messaging;

/// <summary>
/// Publishes messages to RabbitMQ using topic exchange.
/// The NotificationWorker (separate container/process) subscribes and processes them.
///
/// Exchange: inkril.events (topic)
/// Routing keys used:
///   book.published         → notify opted-in users of new book
///   friend.request.sent    → notify receiver of friend request
///   reading.milestone      → notify friends of reading achievement
/// </summary>
public class RabbitMqPublisher : IMessagePublisher, IDisposable
{
    private const string ExchangeName = "inkril.events";
    private readonly IConnection _connection;
    private readonly IModel _channel;
    private readonly ILogger<RabbitMqPublisher> _logger;

    public RabbitMqPublisher(IConfiguration config, ILogger<RabbitMqPublisher> logger)
    {
        _logger = logger;

        var factory = new ConnectionFactory
        {
            HostName = config["RabbitMQ:Host"] ?? "rabbitmq",
            Port = int.Parse(config["RabbitMQ:Port"] ?? "5672"),
            UserName = config["RabbitMQ:Username"] ?? "inkril",
            Password = config["RabbitMQ:Password"] ?? throw new InvalidOperationException("RabbitMQ:Password not configured"),
            VirtualHost = config["RabbitMQ:VirtualHost"] ?? "/"
        };

        _connection = factory.CreateConnection();
        _channel = _connection.CreateModel();

        // Declare durable exchange — survives broker restart
        _channel.ExchangeDeclare(ExchangeName, ExchangeType.Topic, durable: true, autoDelete: false);
    }

    public Task PublishAsync<T>(T message, string routingKey, CancellationToken ct = default)
        where T : class
    {
        var json = JsonConvert.SerializeObject(message);
        var body = Encoding.UTF8.GetBytes(json);

        var props = _channel.CreateBasicProperties();
        props.ContentType = "application/json";
        props.DeliveryMode = 2; // persistent
        props.Timestamp = new AmqpTimestamp(DateTimeOffset.UtcNow.ToUnixTimeSeconds());

        _channel.BasicPublish(ExchangeName, routingKey, props, body);
        _logger.LogDebug("Published message to {RoutingKey}: {Json}", routingKey, json);

        return Task.CompletedTask;
    }

    public void Dispose()
    {
        _channel.Close();
        _connection.Close();
    }
}
