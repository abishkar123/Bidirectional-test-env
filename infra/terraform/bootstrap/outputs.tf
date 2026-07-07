output "azure_client_id" {
  description = "Set as GitHub secret AZURE_CLIENT_ID"
  value       = azuread_application.github_deploy.client_id
}

output "azure_tenant_id" {
  description = "Set as GitHub secret AZURE_TENANT_ID"
  value       = data.azuread_client_config.current.tenant_id
}

output "deployment_sp_object_id" {
  description = "Set as GitHub secret DEPLOYMENT_SP_OBJECT_ID"
  value       = azuread_service_principal.github_deploy.object_id
}
