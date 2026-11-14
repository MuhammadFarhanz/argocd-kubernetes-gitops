terraform {
  required_version = ">=1.15.7"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
}

locals {
  node_ips        = [for node in var.nodes : node.ip]
  control_node_ip = local.node_ips[0]
  
  cluster_endpoint = "https://${local.control_node_ip}:6443"
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_endpoint" {
  type = string
}

variable "talos_image_factory_id" {
  type        = string
  description = "The schematic hash from Talos Image Factory"
}

variable "nodes" {
  description = "List of nodes and their configurations"
  type = list(object({
    hostname = string
    ip       = string
    cores    = number
    memory   = number
    type     = string
  }))
}

variable "talos_version" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "cluster_name" {
  type = string
}

provider "proxmox" {
  insecure = true
  endpoint = var.proxmox_endpoint
  api_token = var.api_token

  ssh {
    agent    = true
    username = "root"
  }
}

resource "proxmox_download_file" "talos_image" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = "proxmox-han"
  url                     = "https://factory.talos.dev/image/${var.talos_image_factory_id}/v${var.talos_version}/nocloud-amd64.raw.xz"
  decompression_algorithm = "zst"
  file_name               = "talos-v${var.talos_version}-nocloud-amd64.img"
  overwrite               = false
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each    = { for node in var.nodes : node.hostname => node }
  name        = each.key
  description = "Managed by Terraform"
  tags        = ["terraform", "talos"]
  node_name   = "proxmox-han"
  machine     = "q35"
  bios        = "ovmf"

  efi_disk {
    datastore_id      = "local" # Where to save the tiny EFI vars file
    file_format       = "raw"   # Standard format for EFI vars
    pre_enrolled_keys = false   # Talos doesn't strictly need secure boot keys pre-loaded
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = "local"
    file_id      = proxmox_download_file.talos_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }

  initialization {
    datastore_id = "local"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "192.168.1.1"
      }
    }
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
    floating  = each.value.memory
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }
}

resource "talos_machine_secrets" "machine_secrets" {
  talos_version = "v${var.talos_version}"
}

data "talos_machine_configuration" "cp" {
  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.machine_secrets.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.kubernetes_version}"

  # config_patches = [
  #   yamlencode({
  #     cluster = {
  #       network = {
  #         cni = {
  #           name = "none"
  #         }
          
  #       }
  #     }
  #   }),
    # yamlencode({
    #   cluster = {
    #     proxy = {
    #       disable = true
    #     }
    #   }
    # })
  # ]
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  machine_type       = "worker"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.machine_secrets.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.kubernetes_version}"

  config_patches = []
}

resource "talos_machine_configuration_apply" "cp" {
  depends_on                  = [proxmox_virtual_environment_vm.talos]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.cp.machine_configuration
  node                        = local.control_node_ip
}

resource "talos_machine_configuration_apply" "worker" {
  for_each                    = { for node in var.nodes : node.hostname => node if node.type == "worker" }
  depends_on                  = [proxmox_virtual_environment_vm.talos]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ip
}

data "talos_client_configuration" "client_config" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  nodes                = [local.control_node_ip]
  endpoints            = [local.control_node_ip]
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [talos_machine_configuration_apply.cp]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.control_node_ip
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.control_node_ip
}

data "talos_cluster_health" "health" {
  # for_each             = { for node in var.nodes : node.hostname => node if node.type == "worker" }
  depends_on           = [talos_machine_configuration_apply.cp, talos_machine_configuration_apply.worker]
  client_configuration = data.talos_client_configuration.client_config.client_configuration
  control_plane_nodes  = [local.control_node_ip]
  worker_nodes         = ["192.168.1.101", "192.168.1.102"]
  endpoints            = data.talos_client_configuration.client_config.endpoints
}

output "talosconfig" {
  value     = data.talos_client_configuration.client_config.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

# write your Kubeconfig directly to your ~/.kube directory
resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  filename = "${pathexpand("~")}/.kube/config"

  file_permission = "0600"
}

# write your Talosconfig directly to your ~/.talos directory
resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.client_config.talos_config
  filename = "${pathexpand("~")}/.talos/config"

  file_permission = "0600"
}                          
                                                                                           