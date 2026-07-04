resource "azurerm_log_analytics_data_export_rule" "export" {
  name                    = "export-audit-logs"
  resource_group_name     = var.resource_group_name
  workspace_resource_id   = var.law_id
  destination_resource_id = var.audit_storage_id
  table_names = [
    "AzureActivity",
    "AppTraces",
    "AppRequests",
    "AppExceptions",
    "AzureDiagnostics",
  ]
  enabled = true
}
