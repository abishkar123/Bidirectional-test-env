using Bidirectional.Web.Models;
using Bidirectional.Web.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Bidirectional.Web.Pages.Releases;

public class ReleasesModel(AuditStorageService storage) : PageModel
{
    public IReadOnlyList<ReleaseEvidence> Releases { get; private set; } = [];
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        try { Releases = await storage.GetReleasesAsync(ct); }
        catch (Exception ex) { Error = ex.Message; }
    }
}
