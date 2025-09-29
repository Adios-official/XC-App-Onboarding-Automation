# ==============================================================================
# === Core Load Balancer Attributes ===
# ==============================================================================

variable "lb_name" {
  description = "The name of the load balancer."
  type        = string
}

variable "namespace" {
  description = "The namespace where the load balancer resides."
  type        = string
}

variable "domains" {
  description = "The domain names to associate with the load balancer."
  type        = list(string)
}

variable "lb_labels" {
  description = "Labels for the load balancer."
  type        = map(string)
  default     = {}
}

variable "lb_count" {
  description = "The number of load balancers to create."
  type        = number
}

# ==============================================================================
# === HTTPS & Certificate Configuration ===
# ==============================================================================

variable "lb_type" {
  description = "The HTTPS type. Must be 'https' or 'https_auto_cert'."
  type        = string
  default     = "https_auto_cert"

  validation {
    condition     = contains(["https", "https_auto_cert"], var.lb_type)
    error_message = "Invalid lb_type. Must be 'https' or 'https_auto_cert'."
  }
}

variable "lb_port" {
  description = "HTTPS port for the load balancer to listen on."
  type        = number
  default     = 443
}

variable "add_hsts" {
  description = "Enable HSTS."
  type        = bool
  default     = false
}

variable "http_redirect" {
  description = "Enable HTTP to HTTPS redirect."
  type        = bool
  default     = true
}

variable "custom_cert_names" {
  description = "A list of pre-uploaded custom certificate names to attach."
  type        = list(string)
  default     = []
}

variable "custom_cert_namespace" {
  description = "The namespace where the custom certificates are stored."
  type        = string
  default     = "shared"
}

variable "no_mtls" {
  description = "Disable mutual TLS on the LB listener."
  type        = bool
  default     = true
}

# ==============================================================================
# === Security & Feature Configuration ===
# ==============================================================================

variable "ip_threat_categories" {
  description = "IP threat categories for reputation."
  type        = list(string)
  default     = ["SPAM_SOURCES","WINDOWS_EXPLOITS","WEB_ATTACKS","BOTNETS","SCANNERS","REPUTATION","PHISHING","PROXY","TOR_PROXY","MOBILE_THREATS","DENIAL_OF_SERVICE","NETWORK"]
}

variable "enable_bot_defense" {
  description = "Enable or disable bot defense."
  type        = bool
  default     = false
}

variable "enable_app_firewall" {
  description = "If true, attach the App Firewall specified by app_firewall_name."
  type        = bool
  default     = false
}

variable "app_firewall_name" {
  description = "Name of the existing application firewall to use."
  type        = string
  default     = ""
}

variable "csrf_policy_mode" {
  description = "The CSRF policy mode. Must be one of: all_domains, custom_domains, disabled."
  type        = string
  default     = "disabled"

  validation {
    condition     = contains(["all_domains", "custom_domains", "disabled"], var.csrf_policy_mode)
    error_message = "Invalid csrf_policy_mode. Must be 'all_domains', 'custom_domains', or 'disabled'."
  }
}

variable "csrf_custom_domains" {
  description = "A list of domains to use for the custom CSRF policy."
  type        = list(string)
  default     = []
}

variable "enable_malicious_user_detection" {
  description = "Enable detection for malicious users."
  type        = bool
  default     = false
}

variable "disable_api_discovery" {
  description = "Disable API Discovery."
  type        = bool
  default     = false
}

variable "enable_csrf" {
  description = "If true, enables CSRF protection based on the csrf_policy_mode."
  type        = bool
  default     = false
}
# ==============================================================================
# === Origin Pool Reference ===
# ==============================================================================

variable "origin_pool_name" {
  description = "The name of the origin pool to associate with the load balancer."
  type        = string
}

# ==============================================================================
# === Advertisement Configuration ===
# ==============================================================================

variable "advertise_on_public_default_vip" {
  description = "Enable or disable advertisement on public default VIP."
  type        = bool
  default     = false
}

variable "advertise_custom" {
  description = "Enable or disable custom advertisement."
  type        = bool
  default     = false
}

variable "custom_site_name" {
  description = "The name of the site for custom advertisement."
  type        = string
  default     = ""
}

variable "site_network" {
  description = "The network for custom advertisement."
  type        = string
  default     = ""
}