namespace Bidirectional.Web.Models;

public record ReleaseEvidence(
    string RunNumber,
    string Version,
    string Commit,
    string Branch,
    string Actor,
    DateTimeOffset DeployedAt,
    string AppName,
    string ResourceGroup,
    bool SlotSwap)
{
    public string ShortCommit => Commit.Length >= 7 ? Commit[..7] : Commit;
}

public record SbomEntry(
    string RunNumber,
    string BlobName,
    DateTimeOffset LastModified,
    bool IsSigned)
{
    public string DisplayName => System.IO.Path.GetFileName(BlobName);
}

public record ProvenanceEntry(
    string RunNumber,
    string BlobName,
    DateTimeOffset LastModified,
    bool IsSigned)
{
    public string DisplayName => System.IO.Path.GetFileName(BlobName);
}

public record PolicyEntry(
    string Resource,
    string Policy,
    string State)
{
    public bool IsCompliant => State.Equals("Compliant", StringComparison.OrdinalIgnoreCase);
}

public record ScanResultEntry(string RunNumber, string BlobName, DateTimeOffset LastModified, long SizeBytes);

public record ContainerSummary(
    string Name,
    int BlobCount,
    long TotalBytes,
    DateTimeOffset? LastModified);
