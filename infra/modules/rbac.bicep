// Stage 1 — Fix deployment identity RBAC
// Removes implicit Contributor and grants Website Contributor + Key Vault Secrets User only.
targetScope = 'resourceGroup'

@description('Object ID of sp-bidirectional-dev-deploy')
param deploymentSpObjectId string

@description('Object ID of the App Service system-assigned managed identity (Stage 8)')
param appServiceManagedIdentityObjectId string = ''

@description('Name of the Key Vault for Stage 8 runtime access')
param kvName string

@description('Name of the audit storage account the App Service reads blob containers from')
param auditStorageAccountName string = 'stbidirectionalaudit'

// Built-in role definition IDs (consistent across all Azure environments)
var websiteContributorRoleId = 'de139f84-1756-47ae-9be6-808fbbe84772'
var kvSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// ── Stage 1.3: Website Contributor on the resource group ─────────────────────
resource websiteContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Deterministic GUID so re-runs are idempotent
  name: guid(resourceGroup().id, deploymentSpObjectId, websiteContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', websiteContributorRoleId)
    principalId: deploymentSpObjectId
    principalType: 'ServicePrincipal'
    description: 'Deployment SP — Website Contributor on app resource group (replaces Contributor per Ken standard)'
  }
}

// ── Stage 8: Key Vault Secrets User for App Service managed identity ──────────
resource kvSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(appServiceManagedIdentityObjectId)) {
  name: guid(resourceGroup().id, appServiceManagedIdentityObjectId, kvSecretsUserRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleId)
    principalId: appServiceManagedIdentityObjectId
    principalType: 'ServicePrincipal'
    description: 'App Service managed identity — Key Vault Secrets User for runtime secret access'
  }
}

// ── CI/CD pipeline: Storage Blob Data Contributor on audit storage ────────────
// The deployment SP uploads release evidence, SBOM, provenance, and scan results
// to the private audit containers during each pipeline run.
resource storageBlobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: auditStorage
  name: guid(auditStorage.id, deploymentSpObjectId, storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: deploymentSpObjectId
    principalType: 'ServicePrincipal'
    description: 'Deployment SP — Storage Blob Data Contributor on audit storage for pipeline evidence uploads'
  }
}

// ── Dashboard: Storage Blob Data Reader on audit storage ──────────────────────
// The Razor Pages dashboard reads all five private audit containers using the
// managed identity. Storage Blob Data Reader is the minimum required role.
resource auditStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: auditStorageAccountName
}

resource storageBlobDataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(appServiceManagedIdentityObjectId)) {
  // Scope to the storage account, not the whole resource group
  scope: auditStorage
  name: guid(auditStorage.id, appServiceManagedIdentityObjectId, storageBlobDataReaderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
    principalId: appServiceManagedIdentityObjectId
    principalType: 'ServicePrincipal'
    description: 'App Service managed identity — Storage Blob Data Reader on audit storage for dashboard reads'
  }
}
