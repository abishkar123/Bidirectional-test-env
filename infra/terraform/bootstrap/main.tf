terraform {
  required_version = ">= 1.6"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Local state on purpose: this bootstraps the identity that the main
  # Terraform config's remote backend and CI pipeline depend on, so it
  # can't depend on that identity existing yet. Run this once, locally.
}

provider "azuread" {}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azuread_client_config" "current" {}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azuread_application" "github_deploy" {
  display_name = var.app_display_name
}

resource "azuread_service_principal" "github_deploy" {
  client_id = azuread_application.github_deploy.client_id
}

resource "azuread_application_federated_identity_credential" "staging_env" {
  application_id = azuread_application.github_deploy.id
  display_name   = "github-staging-env"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:environment:staging"
}

resource "azuread_application_federated_identity_credential" "production_env" {
  application_id = azuread_application.github_deploy.id
  display_name   = "github-production-env"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:environment:production"
}

resource "azuread_application_federated_identity_credential" "development_branch" {
  application_id = azuread_application.github_deploy.id
  display_name   = "github-development-branch"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:ref:refs/heads/development"
}

resource "azuread_application_federated_identity_credential" "main_branch" {
  application_id = azuread_application.github_deploy.id
  display_name   = "github-main-branch"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "github_deploy_contributor" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_deploy.object_id
}
