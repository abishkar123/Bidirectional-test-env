using Bidirectional.Web.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Bidirectional.Web.Pages.Audit;

public record AuditLogEntry(
    string Container,
    string ContainerLabel,
    string BlobName,
    string DisplayName,
    DateTimeOffset Timestamp,
    long SizeBytes);

public class AuditModel(AuditStorageService storage) : PageModel
{
    public IReadOnlyList<AuditLogEntry> Entries { get; private set; } = [];
    public string? Error { get; private set; }
    public DateTimeOffset LoadedAt { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        LoadedAt = DateTimeOffset.UtcNow;
        try
        {
            var releasesTask   = storage.GetReleasesAsync(ct);
            var sbomsTask      = storage.GetSbomsAsync(ct);
            var scansTask      = storage.GetScanResultsAsync(ct);
            var provenanceTask = storage.GetProvenanceAsync(ct);

            await Task.WhenAll(releasesTask, sbomsTask, scansTask, provenanceTask);

            var entries = new List<AuditLogEntry>();

            foreach (var r in releasesTask.Result)
                entries.Add(new AuditLogEntry(
                    "release-audit", "Release",
                    $"{r.RunNumber}/release-evidence.json",
                    $"Release #{r.RunNumber} — {r.Version}",
                    r.DeployedAt, 0));

            foreach (var s in sbomsTask.Result)
                entries.Add(new AuditLogEntry(
                    "sbom-archive", "SBOM",
                    s.BlobName, s.DisplayName,
                    s.LastModified, 0));

            foreach (var s in scansTask.Result)
                entries.Add(new AuditLogEntry(
                    "scan-results", "Scan",
                    s.BlobName, s.BlobName,
                    s.LastModified, s.SizeBytes));

            foreach (var p in provenanceTask.Result)
                entries.Add(new AuditLogEntry(
                    "provenance-archive", "Provenance",
                    p.BlobName, p.DisplayName,
                    p.LastModified, 0));

            Entries = entries.OrderByDescending(e => e.Timestamp).ToList();
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
    }
}
