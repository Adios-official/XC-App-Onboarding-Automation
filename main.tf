# ==============================================================================
# --- Local Variables ---
# ==============================================================================

# Creates a map from the list of load balancers for easier and more reliable iteration.
# The key for the map is the list index (0, 1, 2, ...).
locals {
  lb_map = { for index, lb in var.load_balancers : index => lb }
}

# ==============================================================================
# --- Health Check Module ---
# ==============================================================================

# This module is created for each LB where an origin pool AND a health check are enabled.
module "healthcheck" {
  source   = "./modules/healthcheck"
  for_each = { 
    for idx, lb in local.lb_map : idx => lb 
    if lb.create_origin_pool && lb.attach_healthcheck 
  }

  healthcheck_name      = var.healthcheck_name
  namespace             = var.namespace
  healthcheck_type      = var.healthcheck_type
  healthcheck_http_path = var.healthcheck_http_path
}
# ==============================================================================
# --- Origin Pool Module ---
# ==============================================================================

# This module creates new origin pools.
# It iterates over the lb_map and only creates an instance if the 'create_origin_pool'
# flag for that load balancer is set to true.
module "origin_pool" {
  source = "./modules/origin_pool"

  for_each = { for idx, lb in local.lb_map : idx => lb if lb.create_origin_pool }

  # --- Core Attributes ---
  # These values are sourced from the top-level variables defined in your variables.tf
  origin_pool_name         = var.origin_pool_name
  namespace                = var.namespace
  origin_server_type       = var.origin_server_type
  origin_port              = var.origin_port
  origin_labels            = var.origin_labels
  skip_server_verification = var.skip_server_verification
  enable_tls               = var.enable_tls

  # --- Health Check Configuration ---
  attach_healthcheck = each.value.attach_healthcheck
  healthcheck_name      = var.healthcheck_name

  # --- Site Configuration ---
  network_type = var.network_type
  site_locator_type  = var.site_locator_type
  vsite_or_site_name = var.vsite_or_site_name

  # --- Origin Server Type Specific Parameters ---
  # These arguments use conditional logic to pass a value only if the
  # origin_server_type matches, otherwise they pass 'null'.
  k8s_service_name = var.origin_server_type == "k8s_service" ? var.k8s_service_name : null
  ip_address_private = var.origin_server_type == "private_ip" ? var.ip_address_private : null
  dns_name_private = var.origin_server_type == "private_name" ? var.dns_name_private : null
  ip_address_public = var.origin_server_type == "public_ip" ? var.ip_address_public : null
  dns_name_public = var.origin_server_type == "public_name" ? var.dns_name_public : null
}

# ==============================================================================
# --- (New) App Firewall Module ---
# ==============================================================================

# This module is called for each LB where 'enable_app_firewall' AND 'create_new_waf' are true.
module "app_firewall" {
  source   = "./modules/app_firewall"
  for_each = {
    for idx, lb in local.lb_map : idx => lb
    if lb.enable_app_firewall && lb.create_new_waf
  }

  app_firewall_name = each.value.app_firewall_name
  namespace         = var.waf_namespace
}
# ==============================================================================
# --- HTTP Load Balancer Module ---
# ==============================================================================

# This module creates the HTTP load balancers.
# It iterates over every load balancer defined in the lb_map.
module "http_load_balancer" {
  source   = "./modules/http_load_balancer"
  for_each = local.lb_map

  # --- Core Attributes ---
  lb_name   = each.value.lb_name
  lb_count = 1
  namespace = var.namespace # Note: Using the global namespace for all LBs in this workspace
  domains   = each.value.domains
  lb_labels = each.value.lb_labels

  # --- HTTPS & Certificate Configuration ---
  lb_type               = each.value.lb_type
  lb_port               = each.value.lb_port
  add_hsts              = each.value.add_hsts
  http_redirect         = each.value.http_redirect
  custom_cert_names     = split(",", each.value.custom_cert_names)
  custom_cert_namespace = each.value.custom_cert_namespace
  no_mtls               = true # Hardcoded value

  # --- Security & Feature Configuration ---
  ip_threat_categories               = each.value.ip_threat_categories
  enable_bot_defense                 = each.value.enable_bot_defense
  enable_app_firewall                = each.value.enable_app_firewall
  app_firewall_name                  = each.value.create_new_waf ? module.app_firewall[each.key].name : each.value.app_firewall_name
  enable_csrf                        = each.value.enable_csrf
  csrf_policy_mode                   = each.value.csrf_policy_mode
  csrf_custom_domains                = split(",", each.value.csrf_custom_domains)
  enable_malicious_user_detection    = false # Hardcoded value

  # --- Advertisement Configuration ---
  advertise_on_public_default_vip = each.value.advertise_on_public_default_vip
  advertise_custom                = each.value.advertise_custom
  advertise_site_name             = each.value.advertise_site_name 
  site_network                    = each.value.site_network
  advertise_where                 = each.value.advertise_where
  vsite_namespace                 = each.value.vsite_namespace
  

  # --- Origin Pool Selection ---
  # This conditionally selects the name of the newly created pool (by referencing the
  # origin_pool module with the same key) or uses the name of a pre-existing pool.
  origin_pool_name = each.value.create_origin_pool ? module.origin_pool[each.key].origin_pool_name : each.value.existing_origin_pool_name
}
