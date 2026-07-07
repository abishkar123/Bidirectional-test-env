terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-bidirectional-dev-app"
    storage_account_name = "stbidirectionaltfstate"
    container_name       = "tfstate"
    key                  = "bidirectional.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  prefix             = "bidirectional"
  app_name           = "app-${local.prefix}-${var.environment}-api"
  kv_name            = "kv-${local.prefix}-${var.environment}"
  law_name           = "law-${local.prefix}-${var.environment}"
  appi_name          = "appi-${local.prefix}-${var.environment}"
  audit_storage_name = "st${local.prefix}audit"
  action_group_name  = "ag-${local.prefix}-${var.environment}-oncall"
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

module "storage" {
  source              = "./modules/storage"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  audit_storage_name  = local.audit_storage_name
}

module "key_vault" {
  source              = "./modules/key-vault"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  kv_name             = local.kv_name
}

module "observability" {
  source              = "./modules/observability"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  law_name            = local.law_name
  appi_name           = local.appi_name
}

module "app_service" {
  source                 = "./modules/app-service"
  location               = var.location
  resource_group_name    = data.azurerm_resource_group.main.name
  app_name               = local.app_name
  appi_connection_string = module.observability.appi_connection_string
  kv_name                = local.kv_name
  environment            = var.environment
  depends_on             = [module.observability, module.key_vault]
}

module "deployment_slot" {
  source                 = "./modules/deployment-slot"
  app_service_id         = module.app_service.app_service_id
  appi_connection_string = module.observability.appi_connection_string
  kv_name                = local.kv_name
  audit_storage_name     = local.audit_storage_name
  depends_on             = [module.app_service, module.observability]
}

module "rbac" {
  source                    = "./modules/rbac"
  resource_group_id         = data.azurerm_resource_group.main.id
  deployment_sp_object_id   = var.deployment_sp_object_id
  app_service_mi_object_id  = module.app_service.principal_id
  staging_slot_mi_object_id = module.deployment_slot.principal_id
  audit_storage_id          = module.storage.storage_id
  depends_on                = [module.app_service, module.deployment_slot]
}

module "alerts" {
  source              = "./modules/alerts"
  resource_group_name = data.azurerm_resource_group.main.name
  appi_id             = module.observability.appi_id
  app_service_id      = module.app_service.app_service_id
  action_group_name   = local.action_group_name
  alert_email_address = var.alert_email_address
  depends_on          = [module.observability, module.app_service]
}

module "log_export" {
  source              = "./modules/log-export"
  resource_group_name = data.azurerm_resource_group.main.name
  law_id              = module.observability.law_id
  audit_storage_id    = module.storage.storage_id
  depends_on          = [module.observability, module.storage]
}

module "audit_containers" {
  source             = "./modules/audit-storage"
  storage_account_id = module.storage.storage_id
  depends_on         = [module.storage]
}

module "policy" {
  source = "./modules/policy"
}
