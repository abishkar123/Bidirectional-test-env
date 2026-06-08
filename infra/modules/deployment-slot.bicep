// Stage 7 — Deployment slot for blue-green rollback under 2 minutes via slot swap
targetScope = 'resourceGroup'

param appName string

// The production slot environment — set to Development while on dev stage
@allowed(['Development', 'Staging', 'Production'])
param productionSlotEnvironment string = 'Development'

resource appService 'Microsoft.Web/sites@2023-12-01' existing = {
  name: appName
}

// Staging slot — pipeline deploys here, smoke tests run, then swap to production
resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: appService
  name: 'staging'
  location: resourceGroup().location
  properties: {
    serverFarmId: appService.properties.serverFarmId
    httpsOnly: true
  }
}

// Stage 7.3 — Slot-sticky environment setting so it stays with the slot after swap
resource stagingSlotConfig 'Microsoft.Web/sites/slots/config@2023-12-01' = {
  parent: stagingSlot
  name: 'appsettings'
  properties: {
    ASPNETCORE_ENVIRONMENT: 'Staging'
  }
}

// Production slot environment setting — sticky so it is never overwritten by a swap
resource productionSlotConfig 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: appService
  name: 'appsettings'
  properties: {
    ASPNETCORE_ENVIRONMENT: productionSlotEnvironment
  }
}

// Mark ASPNETCORE_ENVIRONMENT as sticky so each slot keeps its own value through swaps
resource stickySettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: appService
  name: 'slotConfigNames'
  properties: {
    appSettingNames: ['ASPNETCORE_ENVIRONMENT']
  }
}

output stagingSlotHostname string = stagingSlot.properties.defaultHostName
