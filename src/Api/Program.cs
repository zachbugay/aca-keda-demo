var builder = WebApplication.CreateBuilder(args);
builder.Services.AddLogging();

var loggerFactory = builder.Services.BuildServiceProvider().GetRequiredService<ILoggerFactory>();
var logger = loggerFactory.CreateLogger<Program>();

logger.LogInformation("Begin setup...");

var app = builder.Build();

app.MapGet("/", () =>
{
    var machineName = Environment.MachineName;
    var timestamp = DateTime.UtcNow.ToString("o");

    logger.LogInformation($"[{timestamp}] Request handled by replica: {machineName}");

    return Results.Ok(new
    {
        message = "Hello from the KEDA HTTP scaling demo!",
        machineName,
        timestamp
    });
});

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

logger.LogInformation("Setup complete. Running application!");
app.Run();
