variable "external_id" {
  type        = string
  description = "External ID for the AssumeRole policy"
}

variable "tenant_id" {
  type        = string
  description = "Tenant ID"
}

variable "project_id" {
  type        = string
  description = "Project ID"
}

variable "tenant_email" {
  type        = string
  description = "Tenant Email"
}

variable "webhook_url" {
  type        = string
  description = "Miggo Webhook URL"
}
