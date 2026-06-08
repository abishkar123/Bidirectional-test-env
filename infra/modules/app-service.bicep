targetScope = 'resourceGroup'

param location string
param appName string
param appiName string
param kvName string
param environment string

var planName = 'plan-${appName}'

// App Service Plan (B1 — cheapest tier with deployment slots)
resource appPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: planName
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    reserved: false  // Windows
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: kvName
}

resource app 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appPlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v9.0'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environment == 'dev' ? 'Development' : 'Production'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'KeyVault__Name'
          value: keyVault.name
        }
        {
          name: 'AuditStorage__AccountName'
          value: 'stbidirectionalaudit'
        }
      ]
    }
  }
}

output appName string = app.name
output principalId string = app.identity.principalId
output defaultHostname string = app.properties.defaultHostName
