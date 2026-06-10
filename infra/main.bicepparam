using './main.bicep'

// ── Deployment identity ───────────────────────────────────────────────────────
param deploymentSpObjectId = 'e347e057-e600-4544-9cc8-3cac5b365d3f'

// ── Alert notifications ───────────────────────────────────────────────────────
param alertEmailAddress = 'raiabishkar0.5@gmail.com'

// ── App Service managed identity (fill after Stage 8) ────────────────────────
param appServiceManagedIdentityObjectId = '7c557a45-2818-415e-9cd2-1bf41853264b'

// ── Azure account ─────────────────────────────────────────────────────────────
param environment = 'dev'
param location = 'australiaeast'
param subscriptionId = '156c186b-44ba-4fb4-98c1-4ff26e131d41'
