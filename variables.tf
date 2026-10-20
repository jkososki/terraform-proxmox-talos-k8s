variable "talos_version" {
  description = "Talos linux version"
  type        = string
  default     = "1.14.3"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.37.1"
}

variable "talos_system_extensions" {
  description = <<-EOT
    A list of talos system extensions that will be included in the image.
    https://github.com/siderolabs/extensions
  EOT
  type        = list(string)
  default     = []
}

variable "pve_hosts" {
  description = "Proxmox VE hosts that receive the Talos image. Map keys must match the Proxmox node names."
  type = map(object({
    name = string
  }))
  nullable = false
}

variable "iso_datastore" {
  description = "Storage name for ISO images"
  type        = string
  default     = "local"
}

variable "vm_datastore_id" {
  description = "Storage name for VM/Snippets"
  type        = string
  default     = "local-lvm"
}

variable "cluster_name" {
  description = "Name of the Talos and Kubernetes cluster."
  type        = string
  default     = "homelab"
  nullable    = false
}

variable "gateway_ip" {
  description = "IPv4 address of the network gateway used by all nodes."
  type        = string
  default     = "192.168.1.1"
  nullable    = false

  validation {
    condition     = can(cidrnetmask("${var.gateway_ip}/32"))
    error_message = "The gateway_ip must be a valid individual IPv4 address."
  }
}

variable "cidr" {
  description = "Subnet prefix length applied to each node address (for example, 24)."
  type        = number
  default     = 24
}

variable "cluster_vip" {
  description = <<-EOT
    The virtual IPv4 address (no scheme or port) that serves as the cluster endpoint.
  EOT
  type        = string
  default     = "192.168.1.100"
  validation {
    condition     = can(cidrnetmask("${var.cluster_vip}/32"))
    error_message = "The cluster_vip must be a valid individual IPv4 address."
  }
}

variable "controlplane_nodes" {
  description = "Control plane nodes keyed by hostname. Each sets CPU cores, disk and optional extra disk size (GB), memory (MB), static IP, and the Proxmox host (a key of pve_hosts) it runs on."
  type = map(object({
    core_count    = number
    disk_gb       = number
    extra_disk_gb = optional(number, 0)
    memory_mb     = number
    node_ip       = string
    pve_host      = string
  }))
}

variable "worker_nodes" {
  description = "Worker nodes keyed by hostname. Each sets CPU cores, disk and optional extra disk size (GB), memory (MB), static IP, and the Proxmox host (a key of pve_hosts) it runs on."
  type = map(object({
    core_count    = number
    disk_gb       = number
    extra_disk_gb = optional(number, 0)
    memory_mb     = number
    node_ip       = string
    pve_host      = string
  }))
  default  = {}
  nullable = false
}

variable "cilium_version" {
  description = "Cilium Helm chart version to install as the CNI."
  type        = string
  default     = "1.20.3"
}
