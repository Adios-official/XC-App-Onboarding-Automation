# In modules/app_firewall/outputs.tf

output "name" {
  description = "The full name of the created App Firewall."
  value       = volterra_app_firewall.app-firewall.name
}