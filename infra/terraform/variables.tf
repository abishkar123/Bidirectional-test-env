variable "tenant_name" {
  description = "Short tenant identifier used as a naming prefix for all resources (e.g. \"bidirectional\"). Each tenant has its own Azure subscription and its own tfvars/backend config."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Location for all resources"
  type        = string
  default     = "australiaeast"
}

variable "subscription_id" {
  description = "Subscription ID for this tenant"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into (must exist already, per tenant)"
  type        = string
}

variable "deployment_sp_object_id" {
  description = "Object ID of this tenant's deployment service principal (from infra/terraform/bootstrap)"
  type        = string
}

variable "alert_email_address" {
  description = "Alert notification email address"
  type        = string
}
