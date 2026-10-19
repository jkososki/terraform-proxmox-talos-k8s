variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "cidr" {
  type     = number
  nullable = false
}

variable "cluster_name" {
  type     = string
  nullable = false
}

variable "cluster_vip" {
  type     = string
  nullable = false
}

variable "core_count" {
  type     = number
  nullable = false
}

variable "disk_gb" {
  type     = number
  nullable = false
}

variable "extra_disk_gb" {
  type    = number
  default = 0
}

variable "gateway_ip" {
  type     = string
  nullable = false
}

variable "image_id" {
  type     = string
  nullable = false
}

variable "inline_manifests" {
  type    = string
  default = ""
}

variable "iso_datastore_id" {
  type     = string
  nullable = false
}

variable "kubernetes_version" {
  type     = string
  nullable = false
}

variable "machine_secrets" {
  type     = any
  nullable = false
}

variable "machine_type" {
  type     = string
  nullable = false
  validation {
    condition     = contains(["controlplane", "worker"], var.machine_type)
    error_message = "The machine type must be either controlplane or worker"
  }
}

variable "memory_mb" {
  type     = number
  nullable = false
}

variable "node_ip" {
  type     = string
  nullable = false
}

variable "node_hostname" {
  type     = string
  nullable = false
}

variable "pve_host" {
  type     = string
  nullable = false
}

variable "talos_version" {
  type     = string
  nullable = false
}

variable "vm_datastore_id" {
  type     = string
  nullable = false
}

variable "vm_tags" {
  type    = list(string)
  default = []
}
