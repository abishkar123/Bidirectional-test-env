// Stage 5 — Log Analytics continuous data export to WORM audit storage
// Makes the audit trail legally defensible under APRA CPS 234 and ASIC RG271
// because Log Analytics retention alone can be shortened or deleted.
targetScope = 'resourceGroup'

param lawName string
param auditStorageName string
param subscriptionId string

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: lawName
}

resource auditStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: auditStorageName
}

// Continuous export rule — all five required tables
resource exportRule 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = {
  parent: law
  name: 'export-audit-logs'
  properties: {
    destination: {
      resourceId: auditStorage.id
    }
    tableNames: [
      'AzureActivity'
      'AppTraces'
      'AppRequests'
      'AppExceptions'
      'AzureDiagnostics'
    ]
    enable: true
  }
}
