resource "azurerm_role_assignment" "website_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Website Contributor"
  principal_id         = var.deployment_sp_object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.resource_group_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.app_service_mi_object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = var.audit_storage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.deployment_sp_object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_blob_data_reader" {
  scope                = var.audit_storage_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.app_service_mi_object_id
  principal_type       = "ServicePrincipal"
}
