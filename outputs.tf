output "talosconfig" {
  description = "Talos client configuration for use with talosctl."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig for the new cluster."
  value       = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}
