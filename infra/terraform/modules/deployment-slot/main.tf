resource "azurerm_windows_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = var.app_service_id
  https_only     = true

  site_config {
    minimum_tls_version = "1.2"

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v9.0"
    }
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT = "Staging"
  }
}
