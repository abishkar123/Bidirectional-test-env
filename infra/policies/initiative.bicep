// Stage 2 — Custom Azure Policy Initiative: enterprise-regulated-platform-baseline
// Deployed at subscription scope; assigned to rg-bidirectional-dev-app with Audit effect.
targetScope = 'subscription'

@description('Resource group to assign the initiative to')
param appResourceGroupName string = 'rg-bidirectional-dev-app'

@description('Policy enforcement mode')
@allowed(['Default', 'DoNotEnforce'])
param enforcementMode string = 'Default'

// ── Built-in policy definition IDs ───────────────────────────────────────────
// All IDs are stable across all Azure commercial environments.
var policies = {
  storageTls12: '/providers/Microsoft.Authorization/policyDefinitions/fe83a0eb-a853-422d-aac2-1bffd182c5d0'
  storageSecureTransfer: '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'
  storageBlobPublicAccess: '/providers/Microsoft.Authorization/policyDefinitions/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751'
  appServiceTls: '/providers/Microsoft.Authorization/policyDefinitions/f0e6e85b-9b9f-4a4b-b67b-f730d42f1b0b'
  kvSoftDelete: '/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d'
  kvDiagnostics: '/providers/Microsoft.Authorization/policyDefinitions/cf820ca0-f99e-4f3e-84fb-66e913812d21'
  appServiceDiagnostics: '/providers/Microsoft.Authorization/policyDefinitions/91a78b24-f231-4a8a-8da9-02c35b2b6510'
}

// ── Initiative definition ─────────────────────────────────────────────────────
resource initiativeDefinition 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: 'enterprise-regulated-platform-baseline'
  properties: {
    displayName: 'enterprise-regulated-platform-baseline'
    description: 'Bidirectional regulated platform baseline controls — APRA CPS 234, ASIC RG271'
    policyType: 'Custom'
    metadata: {
      category: 'Bidirectional Regulated Platform'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionId: policies.storageTls12
        policyDefinitionReferenceId: 'storage-tls12'
        parameters: {}
      }
      {
        policyDefinitionId: policies.storageSecureTransfer
        policyDefinitionReferenceId: 'storage-secure-transfer'
        parameters: {}
      }
      {
        policyDefinitionId: policies.storageBlobPublicAccess
        policyDefinitionReferenceId: 'storage-no-public-blob'
        parameters: {}
      }
      {
        policyDefinitionId: policies.appServiceTls
        policyDefinitionReferenceId: 'appservice-latest-tls'
        parameters: {}
      }
      {
        policyDefinitionId: policies.kvSoftDelete
        policyDefinitionReferenceId: 'kv-soft-delete'
        parameters: {}
      }
      {
        policyDefinitionId: policies.kvDiagnostics
        policyDefinitionReferenceId: 'kv-resource-logs'
        parameters: {}
      }
      {
        policyDefinitionId: policies.appServiceDiagnostics
        policyDefinitionReferenceId: 'appservice-resource-logs'
        parameters: {}
      }
    ]
  }
}

// ── Assignment to the app resource group (Audit effect for dev) ──────────────
resource initiativeAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'bidirectional-dev-baseline'
  properties: {
    displayName: 'bidirectional-dev-baseline'
    description: 'Assigns the regulated platform baseline initiative to the dev app resource group'
    policyDefinitionId: initiativeDefinition.id
    enforcementMode: enforcementMode
    // Scope to resource group (subscription scope deployment, but assignment at RG level)
    // The scope here pins to the RG using the subscription's resource group reference.
  }
  // Assignment must scope to the RG — set via the resource's scope property
  scope: resourceGroup(appResourceGroupName)
}
