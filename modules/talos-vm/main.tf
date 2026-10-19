locals {
  cluster_endpoint = "https://${var.cluster_vip}:6443"

  patch_kube_proxy = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "KubeProxyConfig"
    enabled    = false
  })

  patch_flannel = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "KubeFlannelCNIConfig"
    "$patch"   = "delete"
  })

  patch_hostname = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "HostnameConfig"
    hostname   = var.node_hostname
    auto       = "off"
  })

  patch_link_config = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "LinkConfig"
    name       = "eth0"
    addresses = [
      { address = "${var.node_ip}/${var.cidr}" }
    ]
    routes = [
      { gateway = var.gateway_ip }
    ]
  })

  patch_layer2_config = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "Layer2VIPConfig"
    name       = var.cluster_vip
    link       = "eth0"
  })

  patch_inline_manifests = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "KubeInlineManifestConfig"
    name       = "init-resources"
    manifest   = var.inline_manifests
  })

}

data "talos_machine_configuration" "this" {

  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  cluster_endpoint = local.cluster_endpoint
  cluster_name     = var.cluster_name
  machine_secrets  = var.machine_secrets
  machine_type     = var.machine_type

  config_patches = compact([
    local.patch_link_config,
    local.patch_layer2_config,
    local.patch_flannel,
    local.patch_kube_proxy,
    local.patch_hostname,
    var.inline_manifests == null || var.inline_manifests == "" ? null : local.patch_inline_manifests
  ])
}

locals {
  vm_name = "${var.node_hostname}-vm"
}

resource "proxmox_virtual_environment_file" "this" {
  content_type = "snippets"
  datastore_id = var.iso_datastore_id
  node_name    = var.pve_host

  source_raw {
    data      = data.talos_machine_configuration.this.machine_configuration
    file_name = "${local.vm_name}-userdata.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  bios            = "ovmf"
  machine         = "q35"
  name            = local.vm_name
  node_name       = var.pve_host
  on_boot         = true
  scsi_hardware   = "virtio-scsi-single"
  stop_on_destroy = true
  tags            = sort(var.vm_tags)

  agent {
    enabled = true
  }

  cpu {
    cores = var.core_count
    type  = "host"
  }

  # OS Disk
  disk {
    datastore_id = var.vm_datastore_id
    discard      = "on"
    file_format  = "raw"
    file_id      = var.image_id
    interface    = "scsi0"
    iothread     = true
    size         = var.disk_gb
    ssd          = true
  }

  # Data Disk
  dynamic "disk" {
    for_each = var.extra_disk_gb > 0 ? [1] : []
    content {
      datastore_id = var.vm_datastore_id
      interface    = "scsi1"
      size         = var.extra_disk_gb
      file_format  = "raw"
      iothread     = true
      discard      = "on"
      ssd          = true
    }
  }

  efi_disk {
    datastore_id      = var.vm_datastore_id
    type              = "4m"
    pre_enrolled_keys = false
  }

  initialization {
    datastore_id      = var.vm_datastore_id
    user_data_file_id = proxmox_virtual_environment_file.this.id
  }

  memory {
    dedicated = var.memory_mb
  }

  network_device {
    bridge = var.bridge
  }

  operating_system {
    type = "l26"
  }

}
