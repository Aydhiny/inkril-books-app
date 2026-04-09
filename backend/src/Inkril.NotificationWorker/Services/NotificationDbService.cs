using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace Inkril.NotificationWorker.Services;

public interface INotificationDbService
{
    Task<IEnumerable<string>> GetNewBookNotificationEmailsAsync();
    Task CreateNotificationAsync(Guid userId, string type, string title, string message, Guid? referenceId = null);
    Task CreateBulkNotificationAsync(string type, string title, string message, Guid? referenceId = null);
    Task<IEnumerable<Guid>> GetFriendIdsAsync(Guid userId);
}

/// <summary>
/// The worker uses a lightweight direct EF query instead of going via the main API,
/// keeping it decoupled but still able to write to the shared database.
/// </summary>
public class NotificationDbService(IConfiguration config, ILogger<NotificationDbService> logger)
    : INotificationDbService
{
    private string ConnectionString =>
        config.GetConnectionString("Default")
        ?? throw new InvalidOperationException("ConnectionStrings:Default not configured");

    public async Task<IEnumerable<string>> GetNewBookNotificationEmailsAsync()
    {
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();

        await using var cmd = new Npgsql.NpgsqlCommand(
            """
            SELECT u."Email"
            FROM "AspNetUsers" u
            INNER JOIN "UserSettings" s ON s."UserId" = u."Id"
            WHERE s."ReceiveNewBookNotifications" = true
              AND u."IsDeleted" = false
              AND u."IsBlocked" = false
            """, conn);

        var emails = new List<string>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            emails.Add(reader.GetString(0));

        return emails;
    }

    public async Task CreateNotificationAsync(
        Guid userId, string type, string title, string message, Guid? referenceId = null)
    {
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();

        await using var cmd = new Npgsql.NpgsqlCommand(
            """
            INSERT INTO "Notifications" ("Id","UserId","Type","Title","Message","IsRead","IsDeleted","CreatedAt","ReferenceId")
            VALUES (@id, @userId, @type, @title, @message, false, false, NOW(), @refId)
            """, conn);

        cmd.Parameters.AddWithValue("id", Guid.NewGuid());
        cmd.Parameters.AddWithValue("userId", userId);
        cmd.Parameters.AddWithValue("type", type);
        cmd.Parameters.AddWithValue("title", title);
        cmd.Parameters.AddWithValue("message", message);
        cmd.Parameters.AddWithValue("refId", (object?)referenceId ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();
        logger.LogDebug("Created notification for user {UserId}: {Title}", userId, title);
    }

    public async Task CreateBulkNotificationAsync(
        string type, string title, string message, Guid? referenceId = null)
    {
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();

        // Get all active user IDs first
        await using var selectCmd = new Npgsql.NpgsqlCommand(
            """SELECT "Id" FROM "AspNetUsers" WHERE "IsDeleted" = false AND "IsBlocked" = false""", conn);
        var userIds = new List<Guid>();
        await using var reader = await selectCmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            userIds.Add(reader.GetGuid(0));
        await reader.CloseAsync();

        foreach (var userId in userIds)
        {
            await using var insertCmd = new Npgsql.NpgsqlCommand(
                """
                INSERT INTO "Notifications" ("Id","UserId","Type","Title","Message","IsRead","IsDeleted","CreatedAt","ReferenceId")
                VALUES (@id, @userId, @type, @title, @message, false, false, NOW(), @refId)
                """, conn);
            insertCmd.Parameters.AddWithValue("id", Guid.NewGuid());
            insertCmd.Parameters.AddWithValue("userId", userId);
            insertCmd.Parameters.AddWithValue("type", type);
            insertCmd.Parameters.AddWithValue("title", title);
            insertCmd.Parameters.AddWithValue("message", message);
            insertCmd.Parameters.AddWithValue("refId", (object?)referenceId ?? DBNull.Value);
            await insertCmd.ExecuteNonQueryAsync();
        }

        logger.LogInformation("Created bulk notifications for {Count} users: {Title}", userIds.Count, title);
    }

    public async Task<IEnumerable<Guid>> GetFriendIdsAsync(Guid userId)
    {
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();

        await using var cmd = new Npgsql.NpgsqlCommand(
            """
            SELECT CASE WHEN "UserId" = @userId THEN "FriendId" ELSE "UserId" END
            FROM "Friendships"
            WHERE ("UserId" = @userId OR "FriendId" = @userId) AND "IsDeleted" = false
            """, conn);
        cmd.Parameters.AddWithValue("userId", userId);

        var ids = new List<Guid>();
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            ids.Add(reader.GetGuid(0));

        return ids;
    }
}
