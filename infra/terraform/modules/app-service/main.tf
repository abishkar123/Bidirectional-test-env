resource "azurerm_service_plan" "plan" {
  name                = "plan-${var.app_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"
  sku_name            = "S1"
}

resource "azurerm_windows_web_app" "app" {
  name                = var.app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v9.0"
    }
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT                = var.environment == "dev" ? "Development" : "Production"
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.appi_connection_string
    "KeyVault__Name"                      = var.kv_name
    "AuditStorage__AccountName"           = "stbidirectionalaudit"
  }

  sticky_settings {
    app_setting_names = ["ASPNETCORE_ENVIRONMENT"]
  }
}
