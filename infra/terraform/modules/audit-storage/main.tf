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

resource "azurerm_storage_container" "rollback_evidence" {
  name                  = "rollback-evidence"
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}

# WORM controls — version-level immutability on the four evidentiary
# containers (7-year retention, matching typical APRA/ASIC record-keeping
# expectations) and a shorter retention on scan-results (lower evidentiary
# weight, refreshed every release). Policies are left unlocked so they can
# be tuned during rollout; lock them (immutability_period_in_days becomes
# irreversible) once retention values are signed off.
resource "azurerm_storage_container_immutability_policy" "release_audit" {
  storage_container_resource_manager_id = azurerm_storage_container.release_audit.resource_manager_id
  immutability_period_in_days           = 2557
}

resource "azurerm_storage_container_immutability_policy" "sbom_archive" {
  storage_container_resource_manager_id = azurerm_storage_container.sbom_archive.resource_manager_id
  immutability_period_in_days           = 2557
}

resource "azurerm_storage_container_immutability_policy" "provenance_archive" {
  storage_container_resource_manager_id = azurerm_storage_container.provenance_archive.resource_manager_id
  immutability_period_in_days           = 2557
}

resource "azurerm_storage_container_immutability_policy" "policy_evidence" {
  storage_container_resource_manager_id = azurerm_storage_container.policy_evidence.resource_manager_id
  immutability_period_in_days           = 2557
}

resource "azurerm_storage_container_immutability_policy" "scan_results" {
  storage_container_resource_manager_id = azurerm_storage_container.scan_results.resource_manager_id
  immutability_period_in_days           = 365
}

resource "azurerm_storage_container_immutability_policy" "rollback_evidence" {
  storage_container_resource_manager_id = azurerm_storage_container.rollback_evidence.resource_manager_id
  immutability_period_in_days           = 2557
}
