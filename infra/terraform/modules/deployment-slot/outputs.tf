output "staging_slot_hostname" {
  value = azurerm_windows_web_app_slot.staging.default_hostname
}

output "principal_id" {
  value = azurerm_windows_web_app_slot.staging.identity[0].principal_id
}
