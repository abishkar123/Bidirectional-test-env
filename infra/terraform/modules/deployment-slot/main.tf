resource "azurerm_windows_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = var.app_service_id
  https_only     = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v9.0"
    }
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT                = "Staging"
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.appi_connection_string
    "KeyVault__Name"                      = var.kv_name
    "AuditStorage__AccountName"           = var.audit_storage_name
  }
}
