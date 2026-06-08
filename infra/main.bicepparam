using './main.bicep'

// ── Required — fill these in before deploying ─────────────────────────────────

// Object ID of sp-bidirectional-dev-deploy (from: az ad sp show --display-name sp-bidirectional-dev-deploy --query id -o tsv)
param deploymentSpObjectId = 'REPLACE_WITH_SP_OBJECT_ID'

// Your notification email for Monitor alert rules
param alertEmailAddress = 'REPLACE_WITH_YOUR_EMAIL'

// ── Optional — set after Stage 8 managed identity is enabled ─────────────────
// Object ID from: App Service → Identity → System assigned → Object (principal) ID
param appServiceManagedIdentityObjectId = ''

// ── Defaults (change only if your naming differs) ─────────────────────────────
param environment = 'dev'
param location = 'australiaeast'
param subscriptionId = '00000000-0000-0000-0000-000000000002'
