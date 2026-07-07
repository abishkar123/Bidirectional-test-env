variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the deploy identity needs Contributor on"
  type        = string
  default     = "rg-bidirectional-dev-app"
}

variable "app_display_name" {
  description = "Display name for the GitHub Actions deploy app registration"
  type        = string
  default     = "sp-bidirectional-github-deploy"
}

variable "github_repo" {
  description = "GitHub repo in owner/name form, used in OIDC federated credential subjects"
  type        = string
  default     = "abishkar123/Bidirectional-test-env"
}
