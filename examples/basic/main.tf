module "cluster" {
  source = "../.."

  iso_datastore = "local"
  cluster_name  = "homelab"
  gateway_ip    = "192.168.144.1"
  cluster_vip   = "192.168.144.220"

  pve_hosts = {
    "pve01" = {
      name = "pve01"
    }
    "pve02" = {
      name = "pve02"
    }
    "pve03" = {
      name = "pve03"
    }
  }

  control_plane_nodes = {
    "cp1" = {
      core_count = 2
      disk_gb    = 20
      memory_mb  = 4 * 1024
      node_ip    = "192.168.144.221"
      pve_host   = "pve01"
    }
    "cp2" = {
      core_count = 2
      disk_gb    = 20
      memory_mb  = 4 * 1024
      node_ip    = "192.168.144.222"
      pve_host   = "pve02"
    }
    "cp3" = {
      core_count = 2
      disk_gb    = 20
      memory_mb  = 4 * 1024
      node_ip    = "192.168.144.223"
      pve_host   = "pve03"
    }
  }
}
