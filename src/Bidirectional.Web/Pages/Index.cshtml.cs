using Bidirectional.Web.Models;
using Bidirectional.Web.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Bidirectional.Web.Pages;

public class IndexModel(AuditStorageService storage, PolicyComplianceService policy) : PageModel
{
    public IReadOnlyList<ContainerSummary> ContainerSummaries { get; private set; } = [];
    public IReadOnlyList<PolicyEntry> PolicyEntries { get; private set; } = [];
    public ReleaseEvidence? LatestRelease { get; private set; }
    public int TotalReleases { get; private set; }
    public int TotalSboms { get; private set; }
    public int TotalScans { get; private set; }
    public int CompliantPolicies { get; private set; }
    public int TotalPolicies { get; private set; }
    public string? Error { get; private set; }
    public DateTimeOffset LoadedAt { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        LoadedAt = DateTimeOffset.UtcNow;
        try
        {
            var containersTask   = storage.GetContainerSummariesAsync(ct);
            var releasesTask     = storage.GetReleasesAsync(ct);
            var sbomsTask        = storage.GetSbomsAsync(ct);
            var scansTask        = storage.GetScanResultsAsync(ct);
            var policyTask       = policy.GetLatestPolicyStateAsync(ct);

            await Task.WhenAll(containersTask, releasesTask, sbomsTask, scansTask, policyTask);

            ContainerSummaries = containersTask.Result;
            var releases       = releasesTask.Result;
            var policyEntries  = policyTask.Result;

            LatestRelease      = releases.FirstOrDefault();
            TotalReleases      = releases.Count;
            TotalSboms         = sbomsTask.Result.Count;
            TotalScans         = scansTask.Result.Count;
            PolicyEntries      = policyEntries.Take(10).ToList();
            CompliantPolicies  = policyEntries.Count(p => p.IsCompliant);
            TotalPolicies      = policyEntries.Count;
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
    }
}
