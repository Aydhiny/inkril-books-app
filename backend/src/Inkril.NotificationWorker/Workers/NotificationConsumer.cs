using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace Inkril.NotificationWorker.Workers;

/// <summary>
/// Background worker that consumes messages from RabbitMQ and dispatches
/// async tasks (email, in-app notifications).
///
/// This is the "Pomoćni servis" (auxiliary microservice) required by the professor.
/// It runs in its own Docker container and is NOT part of Inkril.API.
/// Hangfire inside API would NOT satisfy the "two separate services" requirement.
///
/// Subscribed routing keys (via topic exchange inkril.events):
///   book.published         → fan-out new-book notifications to opted-in users
///   friend.request.sent    → create in-app notification for receiver
///   reading.milestone      → notify friends of achievement
/// </summary>
public class NotificationConsumer(
    IConfiguration config,
    ILogger<NotificationConsumer> logger,
    IServiceProvider services) : BackgroundService
{
    private const string ExchangeName = "inkril.events";
    private const string QueueName = "inkril.notifications";
    private IConnection? _connection;
    private IModel? _channel;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await ConnectWithRetryAsync(stoppingToken);

        var consumer = new AsyncEventingBasicConsumer(_channel!);
        consumer.Received += OnMessageReceivedAsync;

        _channel!.BasicConsume(QueueName, autoAck: false, consumer: consumer);
        logger.LogInformation("NotificationWorker listening on queue: {Queue}", QueueName);

        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    private async Task ConnectWithRetryAsync(CancellationToken ct)
    {
        var retries = 0;
        while (!ct.IsCancellationRequested)
        {
            try
            {
                var factory = new ConnectionFactory
                {
                    HostName = config["RabbitMQ:Host"] ?? "rabbitmq",
                    Port = int.Parse(config["RabbitMQ:Port"] ?? "5672"),
                    UserName = config["RabbitMQ:Username"] ?? "inkril",
                    Password = config["RabbitMQ:Password"] ?? throw new InvalidOperationException("RabbitMQ:Password not configured"),
                    VirtualHost = config["RabbitMQ:VirtualHost"] ?? "/",
                    DispatchConsumersAsync = true
                };

                _connection = factory.CreateConnection();
                _channel = _connection.CreateModel();

                _channel.ExchangeDeclare(ExchangeName, ExchangeType.Topic, durable: true);
                _channel.QueueDeclare(QueueName, durable: true, exclusive: false, autoDelete: false);

                // Bind to all event types this worker handles
                foreach (var key in new[] { "book.published", "friend.request.sent", "reading.milestone" })
                    _channel.QueueBind(QueueName, ExchangeName, key);

                _channel.BasicQos(prefetchSize: 0, prefetchCount: 10, global: false);

                logger.LogInformation("Connected to RabbitMQ after {Retries} retries", retries);
                return;
            }
            catch (Exception ex)
            {
                retries++;
                logger.LogWarning("RabbitMQ connection attempt {Retries} failed: {Message}. Retrying in 5s...",
                    retries, ex.Message);
                await Task.Delay(5000, ct);
            }
        }
    }

    private async Task OnMessageReceivedAsync(object sender, BasicDeliverEventArgs ea)
    {
        var routingKey = ea.RoutingKey;
        var body = Encoding.UTF8.GetString(ea.Body.ToArray());

        logger.LogInformation("Received message on {RoutingKey}", routingKey);

        try
        {
            var payload = JObject.Parse(body);

            await (routingKey switch
            {
                "book.published" => HandleBookPublishedAsync(payload),
                "friend.request.sent" => HandleFriendRequestAsync(payload),
                "reading.milestone" => HandleReadingMilestoneAsync(payload),
                _ => Task.CompletedTask
            });

            _channel!.BasicAck(ea.DeliveryTag, multiple: false);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to process message on {RoutingKey}. Nacking.", routingKey);
            // Nack without requeue to avoid infinite loop — send to dead-letter queue in production
            _channel!.BasicNack(ea.DeliveryTag, multiple: false, requeue: false);
        }
    }

    private async Task HandleBookPublishedAsync(JObject payload)
    {
        var bookId = payload["BookId"]?.ToString();
        var bookTitle = payload["BookTitle"]?.ToString();
        var bookAuthor = payload["BookAuthor"]?.ToString();

        logger.LogInformation("New book published: '{Title}' by {Author}", bookTitle, bookAuthor);

        using var scope = services.CreateScope();
        var emailService = scope.ServiceProvider.GetRequiredService<Services.IWorkerEmailService>();
        var dbService = scope.ServiceProvider.GetRequiredService<Services.INotificationDbService>();

        // Get all users who opted in to new book notifications
        var userEmails = await dbService.GetNewBookNotificationEmailsAsync();

        foreach (var email in userEmails)
        {
            await emailService.SendNewBookNotificationAsync(email, bookTitle!, bookAuthor!);
        }

        // Create in-app notifications
        await dbService.CreateBulkNotificationAsync(
            type: "NewBook",
            title: "New book available!",
            message: $"'{bookTitle}' by {bookAuthor} has been added to the library.",
            referenceId: Guid.TryParse(bookId, out var bid) ? bid : null);
    }

    private async Task HandleFriendRequestAsync(JObject payload)
    {
        var receiverId = Guid.Parse(payload["ReceiverId"]!.ToString());
        var senderId = Guid.Parse(payload["SenderId"]!.ToString());

        using var scope = services.CreateScope();
        var dbService = scope.ServiceProvider.GetRequiredService<Services.INotificationDbService>();

        var friendRequestId = Guid.Parse(payload["FriendRequestId"]!.ToString());

        await dbService.CreateNotificationAsync(
            userId: receiverId,
            type: "FriendRequest",
            title: "New friend request",
            message: "Someone wants to be your reading buddy.",
            referenceId: friendRequestId);
    }

    private async Task HandleReadingMilestoneAsync(JObject payload)
    {
        var userId = Guid.Parse(payload["UserId"]!.ToString());
        var milestone = payload["Milestone"]?.ToString() ?? "reading milestone";

        using var scope = services.CreateScope();
        var dbService = scope.ServiceProvider.GetRequiredService<Services.INotificationDbService>();

        // Notify friends of this user
        var friendIds = await dbService.GetFriendIdsAsync(userId);
        foreach (var friendId in friendIds)
        {
            await dbService.CreateNotificationAsync(
                userId: friendId,
                type: "FriendReadingMilestone",
                title: "Your friend reached a milestone!",
                message: $"Your friend has reached a {milestone}.",
                referenceId: userId);
        }
    }

    public override void Dispose()
    {
        _channel?.Close();
        _connection?.Close();
        base.Dispose();
    }
}
