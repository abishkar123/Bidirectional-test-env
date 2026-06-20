resource "azurerm_windows_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = var.app_service_id
  service_plan_id = var.service_plan_id
  https_only     = true

  site_config {
    minimum_tls_version = "1.2"
  }

  app_settings = {
    ASPNETCORE_ENVIRONMENT = "Staging"
  }
}
