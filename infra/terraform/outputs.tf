output "app_service_name" {
  value = local.app_name
}

output "app_service_url" {
  value = "https://${local.app_name}.azurewebsites.net"
}

output "key_vault_name" {
  value = local.kv_name
}

output "audit_storage_name" {
  value = local.audit_storage_name
}
