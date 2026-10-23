output "talosconfig" {
  value     = module.cluster.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}

output "controlplane_nodes" {
  value = module.cluster.controlplane_nodes
}

output "worker_nodes" {
  value = module.cluster.worker_nodes
}
