using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MimeKit;

namespace Inkril.NotificationWorker.Services;

public interface IWorkerEmailService
{
    Task SendNewBookNotificationAsync(string to, string bookTitle, string author);
}

public class WorkerEmailService(IConfiguration config, ILogger<WorkerEmailService> logger) : IWorkerEmailService
{
    public async Task SendNewBookNotificationAsync(string to, string bookTitle, string author)
    {
        var html = $"""
            <h2>📚 New book on Inkril!</h2>
            <p><strong>{bookTitle}</strong> by {author} has just been added to the library.</p>
            <p>Open Inkril to start reading.</p>
            """;

        await SendAsync(to, $"New book: {bookTitle}", html);
    }

    private async Task SendAsync(string to, string subject, string htmlBody)
    {
        try
        {
            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(
                config["Smtp:FromName"] ?? "Inkril",
                config["Smtp:FromEmail"] ?? "noreply@inkril.app"));
            message.To.Add(MailboxAddress.Parse(to));
            message.Subject = subject;
            message.Body = new TextPart("html") { Text = htmlBody };

            using var smtp = new SmtpClient();
            await smtp.ConnectAsync(
                config["Smtp:Host"],
                int.Parse(config["Smtp:Port"] ?? "587"),
                bool.Parse(config["Smtp:UseSsl"] ?? "true") ? SecureSocketOptions.StartTls : SecureSocketOptions.None);

            await smtp.AuthenticateAsync(config["Smtp:Username"], config["Smtp:Password"]);
            await smtp.SendAsync(message);
            await smtp.DisconnectAsync(true);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to send email to {To}", to);
        }
    }
}
