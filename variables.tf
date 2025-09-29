# ==============================================================================
# === F5 XC Provider Variables ===
# ==============================================================================

variable "api_p12_file" {
  description = "REQUIRED: The path to your F5 XC API credential file (.p12)."
  type        = string
}

variable "tenant_name" {
  description = "REQUIRED: Your F5 XC tenant name (e.g., 'your-tenant')."
  type        = string
}

variable "api_url" {
  description = "REQUIRED: The API URL for your F5 XC tenant."
  type        = string
  default     = "https://sdc-support.console.ves.volterra.io/api"
}

variable "namespace" {
  description = "REQUIRED: The namespace for the deployed resources."
  type        = string
}

# ==============================================================================
# === Top-Level Origin Pool Variables ===
# ==============================================================================
# These variables are used to configure a *new* origin pool when the 
# 'create_origin_pool' flag in the load_balancers object is set to true.

variable "origin_pool_name" {
  description = "The name of the new origin pool to create."
  type        = string
  default     = ""
}

variable "origin_server_type" {
  description = "The type of the new origin server (e.g., 'private_name', 'k8s_service')."
  type        = string
  default     = ""
}

variable "origin_port" {
  description = "The port for the new origin server."
  type        = number
  default     = 80
}

variable "origin_labels" {
  description = "A map of labels to apply to the new origin pool."
  type        = map(string)
  default     = {}
}

variable "skip_server_verification" {
  description = "If true, skip server certificate verification for the origin pool."
  type        = bool
  default     = false
}

variable "no_mtls" {
  description = "If true, disable mTLS for the origin pool."
  type        = bool
  default     = true
}

# --- Origin Pool Health check Specific Variables ---

variable "healthcheck_name" {
  description = "The name for the health check resource."
  type        = string
  default     = ""
}
variable "healthcheck_type" {
  description = "The type of health check to create."
  type        = string
  default     = ""
}
variable "healthcheck_http_path" {
  description = "The HTTP path for the health check."
  type        = string
  default     = "/"
}

# --- Origin Server Type Specific Variables ---

variable "k8s_service_name" {
  description = "The name of the Kubernetes service for a 'k8s_service' origin."
  type        = string
  default     = ""
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

# --- Origin Site Variables ---

variable "network_type" {
  description = "The site network type ('inside' or 'outside')."
  type        = string
  default     = ""

  validation {
    condition     = var.network_type == "" || contains(["inside", "outside"], var.network_type)
    error_message = "network_type must be either 'inside' or 'outside'."
  }
}

variable "site_name" {
  description = "The name of the site for the site locator."
  type        = string
  default     = ""
}

# ==============================================================================
# === Main Load Balancer Configuration Object ===
# ==============================================================================

variable "load_balancers" {
  description = "A list of objects, where each object defines a load balancer and its configuration."
  type = list(object({

    # --- Core Attributes ---
    lb_name                         = string
    domains                         = list(string)
    lb_labels                       = optional(map(string), {})

    # --- HTTPS & Certificate Configuration ---
    lb_type                         = optional(string, "https_auto_cert")
    lb_port                         = optional(number, 443)
    add_hsts                        = optional(bool, true)
    http_redirect                   = optional(bool, true)
    custom_cert_names               = optional(string, "")
    custom_cert_namespace           = optional(string, "shared")

    # --- Security & Feature Configuration ---
    ip_threat_categories            = optional(list(string), ["SPAM_SOURCES","WINDOWS_EXPLOITS","WEB_ATTACKS","BOTNETS","REPUTATION","PHISHING","TOR_PROXY","MOBILE_THREATS","DENIAL_OF_SERVICE","NETWORK"])
    enable_bot_defense              = optional(bool, false)
    enable_app_firewall             = optional(bool, false)
    enable_csrf                     = optional(bool, false)
    app_firewall_name               = optional(string)
    csrf_policy_mode                = optional(string, "disabled")
    csrf_custom_domains             = optional(string, "")

    # --- Origin Pool Configuration ---
    create_origin_pool              = bool
    existing_origin_pool_name       = optional(string)
    attach_healthcheck              = optional(bool, false)
    healthcheck_name                = optional(string, "")
    healthcheck_type                = optional(string, "")
    healthcheck_http_path           = optional(string, "/")

    # --- Advertisement Configuration ---
    advertise_on_public_default_vip = bool
    advertise_custom                = bool
    custom_site_name                = optional(string)
    site_network                    = optional(string)

  }))
}