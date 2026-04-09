using Inkril.NotificationWorker.Services;
using Inkril.NotificationWorker.Workers;

var host = Host.CreateDefaultBuilder(args)
    .ConfigureAppConfiguration((ctx, cfg) =>
    {
        cfg.AddJsonFile("appsettings.json", optional: false);
        cfg.AddJsonFile($"appsettings.{ctx.HostingEnvironment.EnvironmentName}.json", optional: true);
        cfg.AddEnvironmentVariables(); // All sensitive config via env vars
    })
    .ConfigureServices((ctx, services) =>
    {
        // Worker service — no API, no controllers, no HTTP pipeline
        services.AddHostedService<NotificationConsumer>();

        // Scoped services (created per-message via IServiceProvider.CreateScope())
        services.AddScoped<IWorkerEmailService, WorkerEmailService>();
        services.AddScoped<INotificationDbService, NotificationDbService>();
    })
    .Build();

await host.RunAsync();
