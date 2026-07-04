output "kv_name" {
  value = azurerm_key_vault.kv.name
}

output "kv_uri" {
  value = azurerm_key_vault.kv.vault_uri
}
