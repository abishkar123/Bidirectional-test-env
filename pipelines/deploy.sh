#!/usr/bin/env bash
# Bidirectional regulated platform — full infrastructure deployment
# Run order:
#   1. policy initiative (subscription scope)
#   2. main stack (resource group scope)
#   3. After Stage 8: re-run main with appServiceManagedIdentityObjectId set
set -euo pipefail

RESOURCE_GROUP="rg-bidirectional-dev-app"
SUBSCRIPTION="00000000-0000-0000-0000-000000000002"
LOCATION="australiaeast"

az account set --subscription "$SUBSCRIPTION"

echo "=== Stage 2: Deploy policy initiative (subscription scope) ==="
az deployment sub create \
  --name "bidirectional-policy-$(date +%Y%m%d%H%M%S)" \
  --location "$LOCATION" \
  --template-file infra/policies/initiative.bicep \
  --parameters appResourceGroupName="$RESOURCE_GROUP" \
  --confirm-with-what-if

echo ""
echo "=== Stages 1,3-7: Deploy main stack (resource group scope) ==="
az deployment group create \
  --name "bidirectional-main-$(date +%Y%m%d%H%M%S)" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --confirm-with-what-if

echo ""
echo "Done. Next:"
echo "  1. Enable system-assigned managed identity on the App Service (Stage 8)"
echo "  2. Copy the Object (principal) ID into main.bicepparam → appServiceManagedIdentityObjectId"
echo "  3. Re-run this script to apply Stage 8 Key Vault RBAC"
