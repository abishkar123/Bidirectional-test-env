using Bidirectional.Web.Models;
using Bidirectional.Web.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Bidirectional.Web.Pages.Sbom;

public class SbomModel(AuditStorageService storage) : PageModel
{
    public IReadOnlyList<SbomEntry> Sboms { get; private set; } = [];
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        try { Sboms = await storage.GetSbomsAsync(ct); }
        catch (Exception ex) { Error = ex.Message; }
    }
}
