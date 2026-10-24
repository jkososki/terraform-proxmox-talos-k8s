locals {
  required_system_extensions = [
    "siderolabs/qemu-guest-agent",
    "siderolabs/util-linux-tools",
  ]
  system_extensions = distinct(concat(local.required_system_extensions, var.talos_system_extensions))
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = local.system_extensions
      }
    }
  })
}

data "talos_image_factory_urls" "this" {
  architecture  = "amd64"
  platform      = "nocloud"
  schematic_id  = talos_image_factory_schematic.this.id
  talos_version = var.talos_version
}

resource "proxmox_download_file" "talos_img" {
  for_each = var.pve_hosts

  content_type            = "iso"
  datastore_id            = var.iso_datastore
  decompression_algorithm = "zst"
  file_name               = "talos-${var.talos_version}-${substr(talos_image_factory_schematic.this.id, 0, 8)}.img"
  node_name               = each.key
  overwrite               = false
  url                     = data.talos_image_factory_urls.this.urls.disk_image
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

module "control_plane" {
  source = "./modules/talos-vm"

  for_each = var.controlplane_nodes

  cidr               = var.cidr
  cluster_name       = var.cluster_name
  cluster_vip        = var.cluster_vip
  core_count         = each.value.core_count
  disk_gb            = each.value.disk_gb
  extra_disk_gb      = lookup(each.value, "extra_disk_gb", 0)
  gateway_ip         = var.gateway_ip
  image_id           = proxmox_download_file.talos_img[each.value.pve_host].id
  inline_manifests   = var.inline_manifests
  iso_datastore_id   = var.iso_datastore
  kubernetes_version = var.kubernetes_version
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  machine_type       = "controlplane"
  memory_mb          = each.value.memory_mb
  node_hostname      = each.key
  node_ip            = each.value.node_ip
  pve_host           = each.value.pve_host
  talos_version      = var.talos_version
  vm_datastore_id    = var.vm_datastore_id
}

module "worker" {
  source = "./modules/talos-vm"

  for_each = var.worker_nodes

  cidr               = var.cidr
  cluster_name       = var.cluster_name
  cluster_vip        = var.cluster_vip
  core_count         = each.value.core_count
  disk_gb            = each.value.disk_gb
  extra_disk_gb      = each.value.extra_disk_gb
  gateway_ip         = var.gateway_ip
  image_id           = proxmox_download_file.talos_img[each.value.pve_host].id
  iso_datastore_id   = var.iso_datastore
  kubernetes_version = var.kubernetes_version
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  machine_type       = "worker"
  memory_mb          = each.value.memory_mb
  node_hostname      = each.key
  node_ip            = each.value.node_ip
  pve_host           = each.value.pve_host
  talos_version      = var.talos_version
  vm_datastore_id    = var.vm_datastore_id
}

locals {
  cp_node_ips = [
    for node_name, node in var.controlplane_nodes : node.node_ip
  ]
  worker_node_ips = [
    for node_name, node in var.worker_nodes : node.node_ip
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = concat(local.cp_node_ips, local.worker_node_ips)
  endpoints            = local.cp_node_ips
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [module.control_plane]

  node                 = local.cp_node_ips[0]
  client_configuration = talos_machine_secrets.this.client_configuration
}

# tflint-ignore: terraform_unused_declarations
data "talos_cluster_health" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = local.cp_node_ips
  worker_nodes         = local.worker_node_ips
  endpoints            = [var.cluster_vip]
  timeouts = {
    read = "5m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [data.talos_cluster_health.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.cp_node_ips[0]
}
