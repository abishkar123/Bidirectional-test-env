using Azure.Identity;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Bidirectional.Web.Models;
using System.Text.Json;

namespace Bidirectional.Web.Services;

/// <summary>
/// Reads the latest policy compliance snapshot from the policy-evidence container.
/// The pipeline uploads a fresh snapshot on every deployment run.
/// </summary>
public sealed class PolicyComplianceService
{
    private readonly BlobServiceClient _client = null!;
    private readonly bool _configured;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public PolicyComplianceService(IConfiguration config)
    {
        var accountName = config["AuditStorage:AccountName"];
        if (string.IsNullOrEmpty(accountName)) return;

        _configured = true;
        _client = new BlobServiceClient(
            new Uri($"https://{accountName}.blob.core.windows.net"),
            new DefaultAzureCredential());
    }

    public async Task<IReadOnlyList<PolicyEntry>> GetLatestPolicyStateAsync(
        CancellationToken ct = default)
    {
        if (!_configured) return [];
        var container = _client.GetBlobContainerClient("policy-evidence");

        // Find the most recent policy-state blob
        BlobItem? latest = null;
        await foreach (var blob in container.GetBlobsAsync(cancellationToken: ct))
        {
            if (!blob.Name.Contains("policy-state")) continue;
            if (latest is null || blob.Properties.LastModified > latest.Properties.LastModified)
                latest = blob;
        }

        if (latest is null) return [];

        var blobClient = container.GetBlobClient(latest.Name);
        var content = await blobClient.DownloadContentAsync(ct);

        var entries = JsonSerializer.Deserialize<List<PolicyEntry>>(
            content.Value.Content.ToString(), JsonOpts);

        return entries ?? [];
    }
}
