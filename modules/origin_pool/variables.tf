# ==============================================================================
# === Core Origin Pool Attributes ===
# ==============================================================================

variable "origin_pool_name" {
  description = "The name of the origin pool."
  type        = string
}

variable "namespace" {
  description = "The namespace in which the origin pool is created."
  type        = string
}

variable "origin_labels" {
  description = "A map of labels to apply to the origin pool."
  type        = map(string)
  default     = {}
}

# ==============================================================================
# === Connection & TLS Settings ===
# ==============================================================================

variable "origin_port" {
  description = "Port for the origin server."
  type        = number
  default     = 80
}

variable "skip_server_verification" {
  description = "If true, skip server certificate verification."
  type        = bool
  default     = false
}

variable "no_mtls" {
  description = "If true, disable mutual TLS for the connection to the origin pool."
  type        = bool
  default     = true
}

# ==============================================================================
# === Origin Server Configuration ===
# ==============================================================================

variable "origin_server_type" {
  description = "Type of origin server (e.g., 'public_name', 'k8s_service', 'private_ip')."
  type        = string
}

# --- Origin Server Type-Specific Variables ---

variable "k8s_service_name" {
  description = "The name of the Kubernetes service for a 'k8s_service' origin."
  type        = string
  # This variable is required when origin_server_type is "k8s_service"
}

variable "ip_address_private" {
  description = "The private IP address for a 'private_ip' or 'vn_private_ip' origin."
  type        = string
  default     = ""
}

variable "ip_address_public" {
  description = "The public IP address for a 'public_ip' origin."
  type        = string
  default     = ""
}

variable "dns_name_private" {
  description = "The private DNS name for a 'private_name' origin."
  type        = string
  default     = ""
}

variable "dns_name_public" {
  description = "The public DNS name for a 'public_name' origin."
  type        = string
  default     = ""
}

# ==============================================================================
# === Site & Network Configuration ===
# ==============================================================================

variable "network_type" {
  description = "The site network type ('inside' or 'outside')."
  type        = string

  validation {
    condition     = contains(["inside", "outside",""], var.network_type)
    error_message = "network_type must be either 'inside' or 'outside'."
  }
}

variable "site_name" {
  description = "The name of the site for the site locator."
  type        = string
}

# ==============================================================================
# === Health check config ===
# ==============================================================================

variable "attach_healthcheck" {
  description = "If true, a health check will be attached to this origin pool."
  type        = bool
  default     = false
}

variable "healthcheck_name" {
  description = "The name of the health check object to attach."
  type        = string
  default     = null
}