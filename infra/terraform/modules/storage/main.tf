resource "azurerm_storage_account" "audit" {
  name                            = var.audit_storage_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  # AAD/RBAC-only access — no storage account keys or SAS tokens, so every
  # write to evidence containers is attributable to a specific principal.
  shared_access_key_enabled = false

  # Blob versioning is a prerequisite for container-level immutability
  # policies (see modules/audit-storage) — without it WORM cannot be applied.
  blob_properties {
    versioning_enabled = true
  }
}
