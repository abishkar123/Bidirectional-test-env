resource "azurerm_storage_container" "release_audit" {
  name                  = "release-audit"
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}

resource "azurerm_storage_container" "sbom_archive" {
  name                  = "sbom-archive"
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}

resource "azurerm_storage_container" "provenance_archive" {
  name                  = "provenance-archive"
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}

resource "azurerm_storage_container" "policy_evidence" {
  name                  = "policy-evidence"
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}

resource "azurerm_storage_container" "scan_results" {
  name                  = "scan-results"
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}
