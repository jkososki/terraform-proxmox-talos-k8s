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

output "controlplane_nodes" {
  description = "Control plane node info."
  value = {
    for k, v in var.controlplane_nodes : k => {
      vm_id      = module.control_plane[k].vm_id
      interfaces = module.control_plane[k].network_interfaces
    }
  }
}

output "worker_nodes" {
  description = "Worker node info."
  value = {
    for k, v in var.worker_nodes : k => {
      vm_id      = module.worker[k].vm_id
      interfaces = module.worker[k].network_interfaces
    }
  }
}
