using Inkril.Application.Common.Interfaces;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MimeKit;

namespace Inkril.Infrastructure.Services;

public class EmailService(IConfiguration config, ILogger<EmailService> logger) : IEmailService
{
    public async Task SendAsync(string to, string subject, string htmlBody, CancellationToken ct = default)
    {
        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(
            config["Smtp:FromName"] ?? "Inkril",
            config["Smtp:FromEmail"] ?? throw new InvalidOperationException("Smtp:FromEmail not configured")));
        message.To.Add(MailboxAddress.Parse(to));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = htmlBody };

        var host     = config["Smtp:Host"]     ?? throw new InvalidOperationException("Smtp:Host not configured");
        var port     = int.Parse(config["Smtp:Port"] ?? "587");
        var useSsl   = bool.Parse(config["Smtp:UseSsl"] ?? "true");
        var username = config["Smtp:Username"] ?? throw new InvalidOperationException("Smtp:Username not configured");
        var password = config["Smtp:Password"] ?? throw new InvalidOperationException("Smtp:Password not configured");

        using var smtp = new SmtpClient();
        await smtp.ConnectAsync(
            host, port,
            useSsl ? SecureSocketOptions.StartTls : SecureSocketOptions.None,
            ct);

        await smtp.AuthenticateAsync(username, password, ct);
        await smtp.SendAsync(message, ct);
        await smtp.DisconnectAsync(true, ct);

        logger.LogInformation("Email sent to {To}: {Subject}", to, subject);
    }

    public Task SendTemplatedAsync(string to, string templateName, object templateData, CancellationToken ct = default)
    {
        // TODO: integrate a template engine (e.g. Scriban or Fluid)
        var html = $"<p>Template: {templateName}</p><pre>{System.Text.Json.JsonSerializer.Serialize(templateData)}</pre>";
        return SendAsync(to, templateName, html, ct);
    }
}
