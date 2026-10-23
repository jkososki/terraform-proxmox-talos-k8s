output "vm_id" {
  description = "The proxmox vm id."
  value       = resource.proxmox_virtual_environment_vm.this.vm_id
}

locals {
  ignore_interfaces = ["lo", "bond0", "dummy0", "teql0", "tunl0", "sit0", "ip6tnl0"]
}

output "network_interfaces" {
  description = "List of interface info."
  value = [
    for idx, interface in resource.proxmox_virtual_environment_vm.this.network_interface_names : {
      name          = interface
      mac_address   = resource.proxmox_virtual_environment_vm.this.mac_addresses[idx]
      ip4_addresses = resource.proxmox_virtual_environment_vm.this.ipv4_addresses[idx]
    }
    if !contains(local.ignore_interfaces, interface)
  ]
}
