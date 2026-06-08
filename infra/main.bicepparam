using './main.bicep'

// ── Deployment identity ───────────────────────────────────────────────────────
param deploymentSpObjectId = 'e21d55bf-c19d-492d-8952-1ffd5cb73c02'

// ── Alert notifications ───────────────────────────────────────────────────────
param alertEmailAddress = 'raiabishkar0.5@gmail.com'

// ── App Service managed identity (fill after Stage 8) ────────────────────────
param appServiceManagedIdentityObjectId = '06f480c6-375d-47e9-94f1-0c5fcf13bb8d'

// ── Azure account ─────────────────────────────────────────────────────────────
param environment = 'dev'
param location = 'australiaeast'
param subscriptionId = '156c186b-44ba-4fb4-98c1-4ff26e131d41'
