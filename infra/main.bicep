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

// ── Stage 1: RBAC — Website Contributor only ─────────────────────────────────
module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  params: {
    deploymentSpObjectId: deploymentSpObjectId
    appServiceManagedIdentityObjectId: appServiceManagedIdentityObjectId
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
    appName: appName
  }
}

// ── Stage 4: Monitor Alert Rules ─────────────────────────────────────────────
module alerts 'modules/alerts.bicep' = {
  name: 'alerts'
  dependsOn: [observability]
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
  dependsOn: [observability]
  params: {
    lawName: lawName
    auditStorageName: auditStorageName
    subscriptionId: subscriptionId
  }
}

// ── Stage 6: Audit Storage containers ────────────────────────────────────────
module auditContainers 'modules/audit-storage.bicep' = {
  name: 'auditContainers'
  params: {
    auditStorageName: auditStorageName
  }
}

// ── Stage 7: Deployment slot ──────────────────────────────────────────────────
module slot 'modules/deployment-slot.bicep' = {
  name: 'deploymentSlot'
  params: {
    appName: appName
    productionSlotEnvironment: 'Development'
  }
}
