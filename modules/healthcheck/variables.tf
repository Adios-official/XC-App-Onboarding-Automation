# ==============================================================================
# === Core Health Check Attributes ===
# ==============================================================================

variable "healthcheck_name" {
  description = "The name for the health check resource."
  type        = string
}

variable "namespace" {
  description = "The namespace where the health check will be created."
  type        = string
}

variable "healthcheck_type" {
  description = "The type of health check to create. Must be 'tcp' or 'http'."
  type        = string
  default     = "tcp"
  validation {
    condition     = contains(["tcp", "http"], var.healthcheck_type)
    error_message = "healthcheck_type must be either 'tcp' or 'http'."
  }
}

# ==============================================================================
# === HTTP-Specific Attributes ===
# ==============================================================================

variable "healthcheck_http_path" {
  description = "The HTTP path to use for the health check (required for type 'http')."
  type        = string
  default     = "/"
}