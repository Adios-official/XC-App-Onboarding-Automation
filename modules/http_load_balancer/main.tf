# ==============================================================================
# --- F5 XC HTTP Load Balancer Resource ---
# ==============================================================================

resource "volterra_http_loadbalancer" "http_lb" {
  count     = var.lb_count
  
  # --- Core Attributes ---
  name      = "${var.lb_name}-http-lb"
  namespace = var.namespace
  labels    = var.lb_labels
  domains   = var.domains

  # --- Default Behavior Settings ---
  # These are hardcoded settings for this module's behavior.
  disable_api_definition      = true
  no_challenge                = true
  disable_client_side_defense = true

  # ==============================================================================
  # --- HTTPS & Certificate Configuration ---
  # ==============================================================================
  # The following two dynamic blocks are mutually exclusive. Based on the 'lb_type'
  # variable, only one of these blocks will be created.

  # This block is created ONLY IF lb_type is "https_auto_cert".
  dynamic "https_auto_cert" {
    for_each = var.lb_type == "https_auto_cert" ? [1] : []
    content {
      add_hsts              = var.add_hsts
      http_redirect         = var.http_redirect
      port                  = var.lb_port
      enable_path_normalize = true # Hardcoded as requested
      no_mtls               = true # Hardcoded as requested
    }
  }

  # This block is created ONLY IF lb_type is "https".
  dynamic "https" {
    for_each = var.lb_type == "https" ? [1] : []
    content {
      add_hsts              = var.add_hsts
      http_redirect         = var.http_redirect
      port                  = var.lb_port
      enable_path_normalize = true

      tls_cert_params {
        no_mtls = true # Hardcoded as requested

        # Creates a "certificates" block for each name in the list of custom certs.
        dynamic "certificates" {
          for_each = var.custom_cert_names
          content {
            name      = certificates.value
            namespace = var.custom_cert_namespace
          }
        }
      }
    }
  }

  # ==============================================================================
  # --- Advertisement Configuration ---
  # ==============================================================================

  # Advertise on the public default VIP.
  advertise_on_public_default_vip = var.advertise_on_public_default_vip

  # This block is created ONLY IF 'advertise_custom' is true.
  dynamic "advertise_custom" {
    for_each = var.advertise_custom ? [1] : []
    content {
      advertise_where {
        site {
          network = var.site_network
          site {
            namespace = "system"
            name      = var.custom_site_name
          }
        }
      }
    }
  }

  # ==============================================================================
  # --- Routes Configuration ---
  # ==============================================================================

  routes {
    simple_route {
      http_method = "ANY"
      path {
        prefix = "/"
      }
      origin_pools {
        pool {
          name      = var.origin_pool_name
          namespace = var.namespace
        }
      }
    }
  }

  # ==============================================================================
  # --- Security Policies & Features ---
  # ==============================================================================

  # --- General Security Settings ---
  enable_malicious_user_detection = var.enable_malicious_user_detection
  service_policies_from_namespace = true
  disable_trust_client_ip_headers = true
  user_id_client_ip               = true
  disable_api_discovery           = true

  # --- IP Reputation ---
  enable_ip_reputation {
    ip_threat_categories = var.ip_threat_categories
  }

  # --- Application Firewall (WAF) ---
  # This argument is set to true ONLY when the app_firewall is NOT enabled.
  disable_waf = !var.enable_app_firewall

  # This block is created ONLY IF 'enable_app_firewall' is true.
  dynamic "app_firewall" {
    for_each = var.enable_app_firewall ? [1] : []
    content {
      name      = var.app_firewall_name
      namespace = var.namespace
    }
  }


  # --- CSRF Protection ---
  # This dynamic block creates the entire csrf_policy ONLY IF CSRF is enabled.
  # If var.enable_csrf is false, this block is completely omitted.
  dynamic "csrf_policy" {
    for_each = var.enable_csrf ? [1] : []
    content {
      # Inside this block, we know CSRF is enabled, so we just need to
      # determine which mode to use.
      all_load_balancer_domains = var.csrf_policy_mode == "all_domains" ? true : null
      disabled                  = var.csrf_policy_mode == "disabled" ? true : null

      dynamic "custom_domain_list" {
        for_each = var.csrf_policy_mode == "custom_domains" ? [1] : []
        content {
          domains = var.csrf_custom_domains
        }
      }
    }
  }

  # --- Bot Defense ---

  # This argument is set to true ONLY when 'enable_bot_defense' is false.
  disable_bot_defense = !var.enable_bot_defense

    
  # This block is created ONLY IF 'enable_bot_defense' is true.
  dynamic "bot_defense" {
    for_each = var.enable_bot_defense ? [1] : []
    content {
      regional_endpoint = "EU"
      timeout           = "1000"

      policy {
        js_download_path   = "/common.js"
        disable_mobile_sdk = true
        javascript_mode    = "ASYNC_JS_NO_CACHING"

        js_insert_all_pages {
          javascript_location = "AFTER_HEAD"
        }

        protected_app_endpoints {
          metadata {
            name = "login"
          }
          http_methods = ["METHOD_POST"]
          protocol     = "BOTH"
          any_domain   = true
          web          = true
          path {
            prefix = "/login/"
          }
          flow_label {
            authentication {
              login {
                
              }
            }
          }
          mitigation {
            block {
              status = "OK"
              body   = "string:///VGhlIHJlcXVlc3RlZCBVUkwgd2FzIHJlamVjdGVkLiBQbGVhc2UgY29uc3VsdCB3aXRoIHlvdXIgYWRtaW5pc3RyYXRvci4="
            }
          }
        }
      }
    }
  }
}