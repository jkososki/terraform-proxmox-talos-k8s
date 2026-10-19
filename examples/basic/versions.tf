terraform {
  required_version = "v1.13.1"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.116.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0"
    }
  }
}

# Credentials & Endpoint provided via environment variables.
# https://search.opentofu.org/provider/bpg/proxmox/latest#environment-variables-summary
# PROXMOX_VE_API_TOKEN=<username>@<realm>!<token-id>=<token-value-uuid>
# PROXMOX_VE_ENDPOINT=https://<hostname>:8006
# PROXMOX_VE_INSECURE=true

provider "proxmox" {}
