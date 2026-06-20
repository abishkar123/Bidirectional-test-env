locals {
  policy_definitions = {
    storage_tls12           = "/providers/Microsoft.Authorization/policyDefinitions/fe83a0eb-a853-422d-aac2-1bffd182c5d0"
    storage_secure_transfer = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
    storage_no_public_blob  = "/providers/Microsoft.Authorization/policyDefinitions/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751"
    app_service_tls         = "/providers/Microsoft.Authorization/policyDefinitions/f0e6e85b-9b9f-4a4b-b67b-f730d42f1b0b"
    kv_soft_delete          = "/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
    kv_diagnostics          = "/providers/Microsoft.Authorization/policyDefinitions/cf820ca0-f99e-4f3e-84fb-66e913812d21"
    app_service_diagnostics = "/providers/Microsoft.Authorization/policyDefinitions/91a78b24-f231-4a8a-8da9-02c35b2b6510"
  }
}

resource "azurerm_policy_set_definition" "baseline" {
  name         = "enterprise-regulated-platform-baseline"
  policy_type  = "Custom"
  display_name = "enterprise-regulated-platform-baseline"
  description  = "Bidirectional regulated platform baseline controls — APRA CPS 234, ASIC RG271"

  metadata = jsonencode({
    category = "Bidirectional Regulated Platform"
    version  = "1.0.0"
  })

  policy_definition_reference {
    policy_definition_id = local.policy_definitions.storage_tls12
    reference_id         = "storage-tls12"
  }
  policy_definition_reference {
    policy_definition_id = local.policy_definitions.storage_secure_transfer
    reference_id         = "storage-secure-transfer"
  }
  policy_definition_reference {
    policy_definition_id = local.policy_definitions.storage_no_public_blob
    reference_id         = "storage-no-public-blob"
  }
  policy_definition_reference {
    policy_definition_id = local.policy_definitions.app_service_tls
    reference_id         = "appservice-latest-tls"
  }
  policy_definition_reference {
    policy_definition_id = local.policy_definitions.kv_soft_delete
    reference_id         = "kv-soft-delete"
  }
  policy_definition_reference {
    policy_definition_id = local.policy_definitions.kv_diagnostics
    reference_id         = "kv-resource-logs"
  }
  policy_definition_reference {
    policy_definition_id = local.policy_definitions.app_service_diagnostics
    reference_id         = "appservice-resource-logs"
  }
}

data "azurerm_subscription" "current" {}

resource "azurerm_subscription_policy_assignment" "baseline" {
  name                 = "bidirectional-dev-baseline"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_set_definition.baseline.id
  display_name         = "bidirectional-dev-baseline"
  description          = "Regulated platform baseline controls — APRA CPS 234, ASIC RG271"
  enforce              = var.enforcement_mode
}
