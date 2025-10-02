resource "volterra_app_firewall" "app-firewall" {
  name      = "${var.app_firewall_name}-waf"
  namespace = var.namespace

  # --- Default Configuration ---
  # These settings are hardcoded for simplicity as per your provided code.
  blocking = false
  detection_settings {
    signature_selection_setting {
      default_attack_type_settings = true
      high_medium_accuracy_signatures = true
    }
    enable_suppression         = true
    disable_staging            = true
    enable_threat_campaigns    = true
    default_violation_settings = true
  }
  allow_all_response_codes  = true
  default_anonymization     = true
  use_default_blocking_page = true
}