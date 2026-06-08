using Azure.Identity;
using Bidirectional.Web.Services;
using Microsoft.Extensions.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

// ── Key Vault configuration via managed identity ──────────────────────────────
var kvName = builder.Configuration["KeyVault:Name"];
if (!string.IsNullOrEmpty(kvName))
{
    builder.Configuration.AddAzureKeyVault(
        new Uri($"https://{kvName}.vault.azure.net/"),
        new DefaultAzureCredential());
}

// ── Application Insights ──────────────────────────────────────────────────────
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString =
        builder.Configuration["ApplicationInsights:ConnectionString"]
        ?? builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
});

// ── Health checks ─────────────────────────────────────────────────────────────
var hc = builder.Services.AddHealthChecks();
if (!string.IsNullOrEmpty(kvName))
{
    hc.AddAzureKeyVault(
        new Uri($"https://{kvName}.vault.azure.net/"),
        new DefaultAzureCredential(),
        _ => { },
        name: "keyvault",
        tags: ["ready"]);
}

// ── Application services ──────────────────────────────────────────────────────
builder.Services.AddRazorPages();
builder.Services.AddSingleton<AuditStorageService>();
builder.Services.AddSingleton<PolicyComplianceService>();
builder.Services.AddProblemDetails();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

// Health endpoints for slot swap smoke tests
app.MapGet("/health/live", () => Results.Ok(new { status = "alive" }));
app.MapGet("/health/ready", async (HealthCheckService hcs) =>
{
    var report = await hcs.CheckHealthAsync(r => r.Tags.Contains("ready"));
    return report.Status == Microsoft.Extensions.Diagnostics.HealthChecks.HealthStatus.Healthy
        ? Results.Ok(new { status = "ready" })
        : Results.Json(new { status = report.Status.ToString() }, statusCode: 503);
});

app.MapRazorPages();

app.Run();
