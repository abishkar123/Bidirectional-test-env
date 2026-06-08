// Stage 6 — Audit storage containers for release evidence pack
// Each container type is separate so evidence can be retained, searched,
// and produced independently under audit.
targetScope = 'resourceGroup'

param auditStorageName string

resource auditStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: auditStorageName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: auditStorage
  name: 'default'
}

// Container: deployment evidence JSON per release (pre-existing, declared for completeness)
resource releaseAudit 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'release-audit'
  properties: {
    publicAccess: 'None'
  }
}

// Container: CycloneDX SBOM per release
resource sbomArchive 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'sbom-archive'
  properties: {
    publicAccess: 'None'
  }
}

// Container: SLSA provenance JSON per release
resource provenanceArchive 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'provenance-archive'
  properties: {
    publicAccess: 'None'
  }
}

// Container: Azure Policy compliance state per release
resource policyEvidence 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'policy-evidence'
  properties: {
    publicAccess: 'None'
  }
}

// Container: SAST SARIF and SCA results per release
resource scanResults 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'scan-results'
  properties: {
    publicAccess: 'None'
  }
}
