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

locals {
  cp_nodes = sort(keys(var.controlplane_nodes))
}

data "helm_template" "cilium" {
  chart        = "oci://quay.io/cilium/charts/cilium"
  kube_version = var.kubernetes_version
  name         = "cilium"
  namespace    = "kube-system"
  version      = var.cilium_version
  include_crds = true
  skip_tests   = true

  values = [yamlencode({
    k8sServiceHost       = var.controlplane_nodes[local.cp_nodes[0]].node_ip
    k8sServicePort       = 6443
    kubeProxyReplacement = true

    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    gatewayAPI = {
      enabled = true
    }

    ipam = {
      mode = "kubernetes"
    }

    l2announcements = {
      enabled = true
    }

    operator = {
      replicas = min(length(local.cp_nodes), 2)
    }

    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
  })]
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
  inline_manifests   = data.helm_template.cilium.manifest
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
  node_ips = [
    for node_name, node in var.controlplane_nodes : node.node_ip
  ]
  worker_node_ips = [
    for node_name, node in var.worker_nodes : node.node_ip
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = concat(local.node_ips, local.worker_node_ips)
  endpoints            = local.node_ips
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [module.control_plane]

  node                 = local.node_ips[0]
  client_configuration = talos_machine_secrets.this.client_configuration
}


resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.node_ips[0]
}
