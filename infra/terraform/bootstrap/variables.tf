variable "tenant_name" {
  description = "Short tenant identifier, used as a naming prefix (must match the main config's tenant_name)"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID for this tenant"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the deploy identity needs Contributor on (must exist already, per tenant)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo in owner/name form, used in OIDC federated credential subjects"
  type        = string
}
