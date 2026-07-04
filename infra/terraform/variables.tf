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
  description = "Subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
  default     = "rg-bidirectional-dev-app"
}

variable "deployment_sp_object_id" {
  description = "Object ID of the deployment service principal sp-bidirectional-dev-deploy"
  type        = string
}

variable "alert_email_address" {
  description = "Alert notification email address"
  type        = string
}
