// Stage 3 — Application Insights + Log Analytics workspace
targetScope = 'resourceGroup'

param location string
param lawName string
param appiName string
param appName string

// Log Analytics workspace (must exist before App Insights)
resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Workspace-based Application Insights (Stage 3.1)
resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: appiName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
    RetentionInDays: 90
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Stage 3.2 — Wire App Insights to the App Service via app settings
// The App Service must already exist; this sets the instrumentation key reference.
resource appService 'Microsoft.Web/sites@2023-12-01' existing = {
  name: appName
}

resource appInsightsConnection 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: appService
  name: 'appsettings'
  properties: {
    APPLICATIONINSIGHTS_CONNECTION_STRING: appi.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
    XDT_MicrosoftApplicationInsights_Mode: 'recommended'
  }
}

output lawId string = law.id
output appiId string = appi.id
output appiConnectionString string = appi.properties.ConnectionString
