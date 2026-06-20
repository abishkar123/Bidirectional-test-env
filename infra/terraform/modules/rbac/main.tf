data "azurerm_subscription" "current" {}

locals {
  website_contributor_role_id           = "de139f84-1756-47ae-9be6-808fbbe84772"
  kv_secrets_user_role_id              = "4633458b-17de-408a-b874-0445c86b69e6"
  storage_blob_data_reader_role_id     = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
  storage_blob_data_contributor_role_id = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
  sub_prefix                            = "${data.azurerm_subscription.current.id}/providers/Microsoft.Authorization/roleDefinitions"
}

resource "azurerm_role_assignment" "website_contributor" {
  scope              = var.resource_group_id
  role_definition_id = "${local.sub_prefix}/${local.website_contributor_role_id}"
  principal_id       = var.deployment_sp_object_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  count              = var.app_service_mi_object_id != "" ? 1 : 0
  scope              = var.resource_group_id
  role_definition_id = "${local.sub_prefix}/${local.kv_secrets_user_role_id}"
  principal_id       = var.app_service_mi_object_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope              = var.audit_storage_id
  role_definition_id = "${local.sub_prefix}/${local.storage_blob_data_contributor_role_id}"
  principal_id       = var.deployment_sp_object_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_blob_data_reader" {
  count              = var.app_service_mi_object_id != "" ? 1 : 0
  scope              = var.audit_storage_id
  role_definition_id = "${local.sub_prefix}/${local.storage_blob_data_reader_role_id}"
  principal_id       = var.app_service_mi_object_id
  principal_type     = "ServicePrincipal"
}
