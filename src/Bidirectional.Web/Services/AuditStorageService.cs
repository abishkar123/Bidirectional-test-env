using Azure.Identity;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Bidirectional.Web.Models;
using System.Text.Json;

namespace Bidirectional.Web.Services;

/// <summary>
/// Reads all five audit storage containers using the managed identity credential.
/// All containers are private — access is via RBAC (Storage Blob Data Reader).
/// </summary>
public sealed class AuditStorageService
{
    private readonly BlobServiceClient _client;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly bool _configured;

    public AuditStorageService(IConfiguration config)
    {
        var accountName = config["AuditStorage:AccountName"];
        if (string.IsNullOrEmpty(accountName))
        {
            // Running locally without Azure storage — pages will show an empty state.
            _client = null!;
            return;
        }

        _configured = true;
        _client = new BlobServiceClient(
            new Uri($"https://{accountName}.blob.core.windows.net"),
            new DefaultAzureCredential());
    }

    // ── release-audit ─────────────────────────────────────────────────────────

    public async Task<IReadOnlyList<ReleaseEvidence>> GetReleasesAsync(
        CancellationToken ct = default)
    {
        if (!_configured) return [];
        var container = _client.GetBlobContainerClient("release-audit");
        var results = new List<ReleaseEvidence>();

        await foreach (var blob in container.GetBlobsAsync(cancellationToken: ct))
        {
            if (!blob.Name.EndsWith("release-evidence.json")) continue;
            try
            {
                var blobClient = container.GetBlobClient(blob.Name);
                var content = await blobClient.DownloadContentAsync(ct);
                var evidence = JsonSerializer.Deserialize<ReleaseEvidence>(
                    content.Value.Content.ToString(), JsonOpts);
                if (evidence is not null) results.Add(evidence);
            }
            catch { /* skip malformed blobs */ }
        }

        return results.OrderByDescending(r => r.DeployedAt).ToList();
    }

    // ── sbom-archive ──────────────────────────────────────────────────────────

    public async Task<IReadOnlyList<SbomEntry>> GetSbomsAsync(CancellationToken ct = default)
    {
        if (!_configured) return [];
        var container = _client.GetBlobContainerClient("sbom-archive");
        var allBlobs = new HashSet<string>();
        var sbomBlobs = new List<BlobItem>();

        await foreach (var blob in container.GetBlobsAsync(cancellationToken: ct))
        {
            allBlobs.Add(blob.Name);
            if (!blob.Name.EndsWith(".bundle")) sbomBlobs.Add(blob);
        }

        return sbomBlobs
            .Select(b =>
            {
                var run = b.Name.Split('/').FirstOrDefault() ?? b.Name;
                var isSigned = allBlobs.Contains(b.Name + ".bundle");
                return new SbomEntry(run, b.Name, b.Properties.LastModified ?? DateTimeOffset.MinValue, isSigned);
            })
            .OrderByDescending(s => s.LastModified)
            .ToList();
    }

    // ── provenance-archive ────────────────────────────────────────────────────

    public async Task<IReadOnlyList<ProvenanceEntry>> GetProvenanceAsync(CancellationToken ct = default)
    {
        if (!_configured) return [];
        var container = _client.GetBlobContainerClient("provenance-archive");
        var allBlobs = new HashSet<string>();
        var provBlobs = new List<BlobItem>();

        await foreach (var blob in container.GetBlobsAsync(cancellationToken: ct))
        {
            allBlobs.Add(blob.Name);
            if (!blob.Name.EndsWith(".bundle")) provBlobs.Add(blob);
        }

        return provBlobs
            .Select(b =>
            {
                var run = b.Name.Split('/').FirstOrDefault() ?? b.Name;
                var isSigned = allBlobs.Contains(b.Name + ".bundle");
                return new ProvenanceEntry(run, b.Name, b.Properties.LastModified ?? DateTimeOffset.MinValue, isSigned);
            })
            .OrderByDescending(p => p.LastModified)
            .ToList();
    }

    // ── scan-results ──────────────────────────────────────────────────────────

    public async Task<IReadOnlyList<ScanResultEntry>> GetScanResultsAsync(CancellationToken ct = default)
    {
        if (!_configured) return [];
        var container = _client.GetBlobContainerClient("scan-results");
        var results = new List<ScanResultEntry>();

        await foreach (var blob in container.GetBlobsAsync(cancellationToken: ct))
        {
            var run = blob.Name.Split('/').FirstOrDefault() ?? blob.Name;
            results.Add(new ScanResultEntry(
                run,
                blob.Name,
                blob.Properties.LastModified ?? DateTimeOffset.MinValue,
                blob.Properties.ContentLength ?? 0));
        }

        return results.OrderByDescending(s => s.LastModified).ToList();
    }

    // ── container summaries (dashboard overview) ──────────────────────────────

    public async Task<IReadOnlyList<ContainerSummary>> GetContainerSummariesAsync(
        CancellationToken ct = default)
    {
        if (!_configured) return [];
        var containerNames = new[]
        {
            "release-audit",
            "sbom-archive",
            "provenance-archive",
            "policy-evidence",
            "scan-results"
        };

        var tasks = containerNames.Select(async name =>
        {
            var container = _client.GetBlobContainerClient(name);
            int count = 0;
            long total = 0;
            DateTimeOffset? latest = null;

            await foreach (var blob in container.GetBlobsAsync(cancellationToken: ct))
            {
                count++;
                total += blob.Properties.ContentLength ?? 0;
                if (blob.Properties.LastModified > latest)
                    latest = blob.Properties.LastModified;
            }

            return new ContainerSummary(name, count, total, latest);
        });

        return await Task.WhenAll(tasks);
    }
}
