resource "azurerm_log_analytics_workspace" "law" {
  name                                = var.law_name
  resource_group_name                 = var.resource_group_name
  location                            = var.location
  sku                                 = "PerGB2018"
  retention_in_days                   = 90
  local_authentication_disabled       = true
}

resource "azurerm_application_insights" "appi" {
  name                = var.appi_name
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  retention_in_days   = 90

  internet_ingestion_enabled = true
  internet_query_enabled     = true
}
