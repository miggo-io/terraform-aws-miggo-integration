variable "role_name" {
  type        = string
  description = "Name of the IAM role Miggo assumes; set it to match your IAM naming standards"
  default     = "ClusterInteractionRole"

  validation {
    condition     = can(regex("^[\\w+=,.@-]{1,64}$", var.role_name))
    error_message = "role_name must be 1-64 characters of letters, digits and +=,.@_-."
  }
}

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

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all created resources"
  default     = {}
}
