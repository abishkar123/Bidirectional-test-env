variable "app_service_id" {
  type = string
}

variable "appi_connection_string" {
  type      = string
  sensitive = true
}

variable "kv_name" {
  type = string
}

variable "audit_storage_name" {
  type = string
}
