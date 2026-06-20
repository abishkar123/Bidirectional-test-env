variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "app_name" {
  type = string
}

variable "appi_connection_string" {
  type      = string
  sensitive = true
}

variable "kv_name" {
  type = string
}

variable "environment" {
  type = string
}
