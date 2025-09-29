# ==============================================================================
# --- F5 XC Health Check Resource ---
# ==============================================================================

resource "volterra_healthcheck" "this" {
  name      = var.healthcheck_name
  namespace = var.namespace

  # --- TCP Health Check ---
  # This block is created ONLY IF healthcheck_type is "tcp".
  # It uses the simplest possible TCP check as per the documentation.
  dynamic "tcp_health_check" {
    for_each = var.healthcheck_type == "tcp" ? [1] : []
    content {
      // No additional arguments are required for a basic TCP check.
    }
  }

  # --- HTTP Health Check ---
  # This block is created ONLY IF healthcheck_type is "http".
  # It uses the basic required arguments from the documentation.
  dynamic "http_health_check" {
    for_each = var.healthcheck_type == "http" ? [1] : []
    content {
      use_origin_server_name = true
      path                   = var.healthcheck_http_path
    }
  }
  healthy_threshold = 3
  interval = 15
  timeout = 3
  unhealthy_threshold = 1
}