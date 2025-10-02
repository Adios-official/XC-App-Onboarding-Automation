# ==============================================================================
# --- F5 XC Origin Pool Resource ---
# ==============================================================================

resource "volterra_origin_pool" "origin_pool" {

  # --- Core Attributes ---
  name                   = "${var.origin_pool_name}-pool"
  namespace              = var.namespace
  labels                 = var.origin_labels
  port                   = var.origin_port
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"
  
    # --- TLS Configuration ---
  # The following two settings are mutually exclusive. Based on the var.enable_tls
  # variable, Terraform will either set 'no_tls' or create the 'use_tls' block.

  # This argument is set to true ONLY IF enable_tls is false.
  no_tls = var.enable_tls ? null : true

  # This dynamic block is created ONLY IF enable_tls is true.
  dynamic "use_tls" {
    for_each = var.enable_tls ? [1] : []
    content {
      no_mtls                     = true
      default_session_key_caching = true
      use_host_header_as_sni      = true
      volterra_trusted_ca         = true
      tls_config {
        default_security = true
      }
    }
  }

  # This dynamic block attaches the health check ONLY IF attach_healthcheck is true.
  dynamic "healthcheck" {
    for_each = var.attach_healthcheck ? [1] : []
    content {
      name      = var.healthcheck_name
      namespace = var.namespace
    }
  }
  # --- Origin Server Configuration ---
  # The following dynamic blocks are mutually exclusive. Based on the 
  # 'origin_server_type' variable, only one of these blocks will be created
  # to define the origin servers in the pool.
origin_servers {

  # --- Kubernetes Service Origin ---
  dynamic "k8s_service" {
    for_each = var.origin_server_type == "k8s_service" ? [1] : []
    content {
      service_name    = var.k8s_service_name
      inside_network  = var.network_type == "inside" ? true : null
      outside_network = var.network_type == "outside" ? true : null
      
      # This site_locator now dynamically chooses between 'site' and 'virtual_site'.
      site_locator {
        dynamic "site" {
          for_each = var.site_locator_type == "site" ? [1] : []
          content {
            namespace = "system"
            name      = var.vsite_or_site_name
          }
        }
        dynamic "virtual_site" {
          for_each = var.site_locator_type == "virtual_site" ? [1] : []
          content {
            namespace = "shared"
            name      = var.vsite_or_site_name
          }
        }
      }
    }
  }

  # --- Private IP Origin ---
  dynamic "private_ip" {
    for_each = var.origin_server_type == "private_ip" ? [1] : []
    content {
      ip              = var.ip_address_private
      inside_network  = var.network_type == "inside" ? true : null
      outside_network = var.network_type == "outside" ? true : null
      
      # This site_locator now dynamically chooses between 'site' and 'virtual_site'.
      site_locator {
        dynamic "site" {
          for_each = var.site_locator_type == "site" ? [1] : []
          content {
            namespace = "system"
            name      = var.vsite_or_site_name
          }
        }
        dynamic "virtual_site" {
          for_each = var.site_locator_type == "virtual_site" ? [1] : []
          content {
            namespace = "shared"
            name      = var.vsite_or_site_name
          }
        }
      }
    }
  }

  # --- Private DNS Name Origin ---
  dynamic "private_name" {
    for_each = var.origin_server_type == "private_name" ? [1] : []
    content {
      dns_name        = var.dns_name_private
      inside_network  = var.network_type == "inside" ? true : null
      outside_network = var.network_type == "outside" ? true : null
      
      # This site_locator now dynamically chooses between 'site' and 'virtual_site'.
      site_locator {
        dynamic "site" {
          for_each = var.site_locator_type == "site" ? [1] : []
          content {
            namespace = "system"
            name      = var.vsite_or_site_name
          }
        }
        dynamic "virtual_site" {
          for_each = var.site_locator_type == "virtual_site" ? [1] : []
          content {
            namespace = "shared"
            name      = var.vsite_or_site_name
          }
        }
      }
    }
  }

    # --- Public DNS Name Origin ---
    dynamic "public_name" {
      for_each = var.origin_server_type == "public_name" ? [1] : []
      content {
        dns_name = var.dns_name_public
      }
    }

    # --- Public IP Origin ---
    dynamic "public_ip" {
      for_each = var.origin_server_type == "public_ip" ? [1] : []
      content {
        ip = var.ip_address_public
      }
    }
  }
}
