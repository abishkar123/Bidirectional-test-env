using Bidirectional.Web.Models;
using Bidirectional.Web.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Bidirectional.Web.Pages.Policy;

public class PolicyModel(PolicyComplianceService policy) : PageModel
{
    public IReadOnlyList<PolicyEntry> Entries { get; private set; } = [];
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        try { Entries = await policy.GetLatestPolicyStateAsync(ct); }
        catch (Exception ex) { Error = ex.Message; }
    }
}
