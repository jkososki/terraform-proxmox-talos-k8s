# terraform-proxmox-talos-k8s

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Terraform / OpenTofu module that provisions a highly available [Kubernetes](https://kubernetes.io/) control plane on [Talos Linux](https://www.talos.dev/), running as virtual machines on [Proxmox VE](https://www.proxmox.com/en/products/proxmox-virtual-environment/overview).

## Table of Contents

- [terraform-proxmox-talos-k8s](#terraform-proxmox-talos-k8s)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Limitations](#limitations)
  - [Requirements](#requirements)
    - [Software](#software)
    - [Infrastructure](#infrastructure)
  - [Proxmox Setup](#proxmox-setup)
    - [1. API User](#1-api-user)
    - [2. SSH User](#2-ssh-user)
    - [3. Datastore](#3-datastore)
    - [Credentials](#credentials)
  - [Quick Start](#quick-start)
  - [Accessing the Cluster](#accessing-the-cluster)
  - [Destroying the Cluster](#destroying-the-cluster)
  - [Module Reference](#module-reference)
  - [Usage](#usage)
  - [Requirements](#requirements-1)
  - [Inputs](#inputs)
  - [Outputs](#outputs)
  - [Contributing](#contributing)
  - [License](#license)

## Features

- Builds a Talos image through the [Image Factory](https://factory.talos.dev/) and downloads it to each Proxmox host.
- Creates one Talos control plane VM per entry in `control_plane_nodes`, pinned to the Proxmox host you choose.
- Bootstraps the cluster and exposes a shared virtual IP (VIP) as the Kubernetes API endpoint.
- Installs [Cilium](https://cilium.io/) as the CNI, with kube-proxy replacement, Gateway API, and L2 announcements enabled.
- Always includes the `qemu-guest-agent` and `util-linux-tools` system extensions. Add more with `talos_system_extensions`.
- Returns `kubeconfig` and `talosconfig` as sensitive outputs.

## Limitations

- Only control plane nodes are provisioned. Worker nodes are not yet supported.
- Images are built for `amd64` only.
- Nodes use static IP addresses, and the VIP must be an unused address in the same subnet as the nodes.

## Requirements

### Software

| Tool | Purpose | Required |
| ---- | ------- | :------: |
| [Terraform](https://developer.hashicorp.com/terraform) `>= 1.13.1` or [OpenTofu](https://opentofu.org/) | Runs the module | Yes |
| [talosctl](https://docs.siderolabs.com/talos/v1.14/getting-started/talosctl) | Inspect and manage Talos nodes | Recommended |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Work with the new cluster | Recommended |
| [Task](https://taskfile.dev/) | Run the `plan`, `apply`, and `destroy` tasks in `taskfile.yml` | Optional |

### Infrastructure

- A Proxmox VE node or cluster. The [basic example](examples/basic) uses a three-node cluster.
- Network access from the machine running the module to the Proxmox API (port 8006) and to the nodes over SSH.
- Static IP addresses for each control plane node, plus one for the VIP.

## Proxmox Setup

The module uses the [bpg/proxmox](https://search.opentofu.org/provider/bpg/proxmox/) provider. See its [authentication documentation](https://search.opentofu.org/provider/bpg/proxmox/latest#authentication) for all supported options.

You need three things:

1. An **API user** with permission to manage resources through the Proxmox API.
2. An **SSH user** on each Proxmox host with write access to the snippets directory.
3. A **datastore** that allows snippets.

### 1. API User

Run the following on a Proxmox host, either over SSH or from **Datacenter > Node > Shell**.

1. Create a user in the `pve` realm.

   ```bash
   pveum user add terraform@pve --comment 'Terraform provider account'
   ```

2. Grant permissions.

   ```bash
   pveum acl modify / --user terraform@pve --role Administrator
   ```

   > **NOTE**  
   > `Administrator` is convenient for a lab. For anything else, create a custom role with only the privileges the module needs and assign that role instead.

3. Create an API token.

   ```bash
   pveum user token add terraform@pve tf-provider --privsep=0
   ```

   The output includes the token secret. It is shown only once, so store it securely.

   ```text
   ┌──────────────┬──────────────────────────────────────┐
   │ key          │ value                                │
   ├──────────────┼──────────────────────────────────────┤
   │ full-tokenid │ terraform@pve!tf-provider            │
   │ info         │ {"privsep":"0"}                      │
   │ value        │ <token-secret>                       │
   └──────────────┴──────────────────────────────────────┘
   ```

### 2. SSH User

The provider uploads Talos configuration snippets over SSH. Use `root`, or create a user with write access to `/var/lib/vz`.

### 3. Datastore

Enable snippets on the datastore that holds VM configuration (`local` by default):

```bash
pvesm set local --content iso,vztmpl,backup,snippets,import
```

### Credentials

Copy `.env.example` to `.env` and fill in your values. Task loads this file automatically. You can also export the variables in your shell.

```dotenv
# .env
PROXMOX_VE_ENDPOINT=https://my-proxmox-node:8006
PROXMOX_VE_API_TOKEN=terraform@pve!tf-provider=<token-secret>
PROXMOX_VE_SSH_USERNAME=root
PROXMOX_VE_SSH_PASSWORD=<password>
```

> [!IMPORTANT]
> `PROXMOX_VE_API_TOKEN` must use the format `<full-tokenid>=<token-secret>`. Never commit `.env`; it is listed in `.gitignore`.

## Quick Start

1. Complete the [Proxmox Setup](#proxmox-setup).
2. Copy [`examples/basic`](examples/basic) and edit it for your environment (see [Usage](#usage)).
3. Review and apply the plan from the example directory.

   ```bash
   task plan
   task apply
   ```

   Without Task, run `tofu plan` and `tofu apply` (or the `terraform` equivalents).

## Accessing the Cluster

The `kubeconfig` and `talosconfig` outputs are sensitive. Write them to files with restrictive permissions:

```bash
tofu output -raw kubeconfig > kubeconfig
tofu output -raw talosconfig > talosconfig
chmod 600 kubeconfig talosconfig

export KUBECONFIG="$PWD/kubeconfig"
export TALOSCONFIG="$PWD/talosconfig"

kubectl get nodes
talosctl health
```

## Destroying the Cluster

```bash
task destroy
```

This deletes the VMs and the cluster state. Back up anything you need first.

## Module Reference

The section below is generated by [terraform-docs](https://terraform-docs.io/). Do not edit it by hand.

<!-- BEGIN_TF_DOCS -->
## Usage
```hcl
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

  controlplane_nodes = {
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

  worker_nodes = {
    "w1" = {
      core_count    = 8
      disk_gb       = 20
      extra_disk_gb = 500
      memory_mb     = 48 * 1024
      node_ip       = "192.168.144.231"
      pve_host      = "pve01"
    }
    "w2" = {
      core_count    = 8
      disk_gb       = 20
      extra_disk_gb = 500
      memory_mb     = 48 * 1024
      node_ip       = "192.168.144.232"
      pve_host      = "pve02"
    }
    "w3" = {
      core_count    = 14
      disk_gb       = 20
      extra_disk_gb = 500
      memory_mb     = 48 * 1024
      node_ip       = "192.168.144.233"
      pve_host      = "pve03"
    }
  }
}
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= v1.13.1 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~>3.3.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.116.1 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.12.0 |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | Subnet prefix length applied to each node address (for example, 24). | `number` | `24` | no |
| <a name="input_cilium_version"></a> [cilium\_version](#input\_cilium\_version) | Cilium Helm chart version to install as the CNI. | `string` | `"1.20.3"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Talos and Kubernetes cluster. | `string` | `"homelab"` | no |
| <a name="input_cluster_vip"></a> [cluster\_vip](#input\_cluster\_vip) | The virtual IPv4 address (no scheme or port) that serves as the cluster endpoint. | `string` | `"192.168.1.100"` | no |
| <a name="input_controlplane_nodes"></a> [controlplane\_nodes](#input\_controlplane\_nodes) | Control plane nodes keyed by hostname. Each sets CPU cores, disk and optional extra disk size (GB), memory (MB), static IP, and the Proxmox host (a key of pve\_hosts) it runs on. | <pre>map(object({<br/>    core_count    = number<br/>    disk_gb       = number<br/>    extra_disk_gb = optional(number, 0)<br/>    memory_mb     = number<br/>    node_ip       = string<br/>    pve_host      = string<br/>  }))</pre> | n/a | yes |
| <a name="input_gateway_ip"></a> [gateway\_ip](#input\_gateway\_ip) | IPv4 address of the network gateway used by all nodes. | `string` | `"192.168.1.1"` | no |
| <a name="input_iso_datastore"></a> [iso\_datastore](#input\_iso\_datastore) | Storage name for ISO images | `string` | `"local"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version | `string` | `"1.37.1"` | no |
| <a name="input_pve_hosts"></a> [pve\_hosts](#input\_pve\_hosts) | Proxmox VE hosts that receive the Talos image. Map keys must match the Proxmox node names. | <pre>map(object({<br/>    name = string<br/>  }))</pre> | n/a | yes |
| <a name="input_talos_system_extensions"></a> [talos\_system\_extensions](#input\_talos\_system\_extensions) | A list of talos system extensions that will be included in the image.<br/>https://github.com/siderolabs/extensions | `list(string)` | `[]` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos linux version | `string` | `"1.14.3"` | no |
| <a name="input_vm_datastore_id"></a> [vm\_datastore\_id](#input\_vm\_datastore\_id) | Storage name for VM/Snippets | `string` | `"local-lvm"` | no |
| <a name="input_worker_nodes"></a> [worker\_nodes](#input\_worker\_nodes) | Worker nodes keyed by hostname. Each sets CPU cores, disk and optional extra disk size (GB), memory (MB), static IP, and the Proxmox host (a key of pve\_hosts) it runs on. | <pre>map(object({<br/>    core_count    = number<br/>    disk_gb       = number<br/>    extra_disk_gb = optional(number, 0)<br/>    memory_mb     = number<br/>    node_ip       = string<br/>    pve_host      = string<br/>  }))</pre> | `{}` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig for the new cluster. |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talos client configuration for use with talosctl. |
<!-- END_TF_DOCS -->


## Contributing

Contributions are welcome. Open an issue to discuss larger changes before sending a pull request.

Pre-commit hooks are managed with [prek](https://prek.j178.dev/) and run formatting, linting, security scanning, and documentation generation:

```bash
prek install
prek run --all-files
```

The generated reference section of this README is rebuilt by the `terraform_docs` hook. Edit descriptions in `variables.tf` and `outputs.tf` instead of the README.

## License

Released under the [MIT License](LICENSE).
