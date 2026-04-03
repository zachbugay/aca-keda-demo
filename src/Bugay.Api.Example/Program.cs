var builder = WebApplication.CreateBuilder(args);
builder.Services.AddLogging();

var app = builder.Build();

app.Logger.LogInformation("Begin setup...");

app.MapGet("/", () =>
{
    var machineName = Environment.MachineName;
    var timestamp = DateTime.UtcNow.ToString("o");

    app.Logger.LogInformation("[{Timestamp}] Request handled by replica: {MachineName}", timestamp, machineName);

    return Results.Ok(new
    {
        message = "Hello from the KEDA HTTP scaling demo!",
        machineName,
        timestamp
    });
});

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.Logger.LogInformation("Setup complete. Running application!");
app.Run();
