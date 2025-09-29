# ==============================================================================
# --- F5 XC Origin Pool Resource ---
# ==============================================================================

resource "volterra_origin_pool" "origin_pool" {

  # --- Core Attributes ---
  name                   = "${var.origin_pool_name}-pool"
  namespace              = var.namespace
  labels                 = var.origin_labels
  port                   = var.origin_port
  no_tls                 = true # Hardcoded value
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"
  

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
        site_locator {
          site {
            namespace = "system"
            name      = var.site_name
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
        site_locator {
          site {
            namespace = "system"
            name      = var.site_name
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
        site_locator {
          site {
            namespace = "system"
            name      = var.site_name
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