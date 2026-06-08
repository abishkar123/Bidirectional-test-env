using Bidirectional.Web.Models;
using Bidirectional.Web.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Bidirectional.Web.Pages.Scans;

public class ScansModel(AuditStorageService storage) : PageModel
{
    public IReadOnlyList<ScanResultEntry> Results { get; private set; } = [];
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        try { Results = await storage.GetScanResultsAsync(ct); }
        catch (Exception ex) { Error = ex.Message; }
    }
}
