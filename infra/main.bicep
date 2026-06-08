targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod)')
param environment string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Object ID of the deployment service principal sp-bidirectional-dev-deploy')
param deploymentSpObjectId string

@description('Object ID of the App Service managed identity (set after identity is enabled)')
param appServiceManagedIdentityObjectId string = ''

@description('Alert notification email address')
param alertEmailAddress string

var prefix = 'bidirectional'
var appName = 'app-${prefix}-${environment}-api'
var kvName = 'kv-${prefix}-${environment}'
var lawName = 'law-${prefix}-${environment}'
var appiName = 'appi-${prefix}-${environment}'
var auditStorageName = 'st${prefix}audit'
var actionGroupName = 'ag-${prefix}-${environment}-oncall'

// ── Storage Account (audit blobs, log export destination) ───────────────────
module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    auditStorageName: auditStorageName
  }
}

// ── Key Vault ─────────────────────────────────────────────────────────────────
module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVault'
  params: {
    location: location
    kvName: kvName
  }
}

// ── Stage 3: Application Insights + Log Analytics ────────────────────────────
module observability 'modules/observability.bicep' = {
  name: 'observability'
  params: {
    location: location
    lawName: lawName
    appiName: appiName
  }
}

// ── App Service Plan + App Service ────────────────────────────────────────────
module appService 'modules/app-service.bicep' = {
  name: 'appService'
  dependsOn: [observability, keyVault]
  params: {
    location: location
    appName: appName
    appiName: appiName
    kvName: kvName
    environment: environment
  }
}

// ── Stage 1: RBAC ────────────────────────────────────────────────────────────
module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  dependsOn: [appService]
  params: {
    deploymentSpObjectId: deploymentSpObjectId
    appServiceManagedIdentityObjectId: appServiceManagedIdentityObjectId
    kvName: kvName
  }
}

// ── Stage 4: Monitor Alert Rules ─────────────────────────────────────────────
module alerts 'modules/alerts.bicep' = {
  name: 'alerts'
  dependsOn: [observability, appService]
  params: {
    location: location
    appiName: appiName
    appName: appName
    actionGroupName: actionGroupName
    alertEmailAddress: alertEmailAddress
  }
}

// ── Stage 5: Log Analytics → Audit Storage export ────────────────────────────
module logExport 'modules/log-export.bicep' = {
  name: 'logExport'
  dependsOn: [observability, storage]
  params: {
    lawName: lawName
    auditStorageName: auditStorageName
    subscriptionId: subscriptionId
  }
}

// ── Stage 6: Audit Storage containers ────────────────────────────────────────
module auditContainers 'modules/audit-storage.bicep' = {
  name: 'auditContainers'
  dependsOn: [storage]
  params: {
    auditStorageName: auditStorageName
  }
}

// ── Stage 7: Deployment slot ──────────────────────────────────────────────────
module slot 'modules/deployment-slot.bicep' = {
  name: 'deploymentSlot'
  dependsOn: [appService]
  params: {
    appName: appName
    productionSlotEnvironment: 'Development'
  }
}

output appServiceName string = appName
output appServiceUrl string = 'https://${appName}.azurewebsites.net'
output keyVaultName string = kvName
output auditStorageName string = auditStorageName
