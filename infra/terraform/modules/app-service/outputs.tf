output "app_name" {
  value = azurerm_windows_web_app.app.name
}

output "app_service_id" {
  value = azurerm_windows_web_app.app.id
}

output "service_plan_id" {
  value = azurerm_service_plan.plan.id
}

output "principal_id" {
  value = azurerm_windows_web_app.app.identity[0].principal_id
}

output "default_hostname" {
  value = azurerm_windows_web_app.app.default_hostname
}
