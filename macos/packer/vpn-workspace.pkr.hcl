packer {
  required_plugins {
    tart = {
      version = "= 1.16.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "base_vm" {
  type        = string
  description = "Local Tart VM or OCI image used as the minimal macOS base"
  default     = "ghcr.io/cirruslabs/macos-sequoia-base:latest"
}

variable "vm_name" {
  type        = string
  description = "Name of the resulting local Tart image"
  default     = "vm-vpn-macos-base"
}

source "tart-cli" "vpn_workspace" {
  vm_base_name = var.base_vm
  vm_name      = var.vm_name
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = 50
  display      = "1440x900"
  communicator = "none"
}

build {
  sources = ["source.tart-cli.vpn_workspace"]
}
