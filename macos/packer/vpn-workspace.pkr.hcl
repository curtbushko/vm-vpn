packer {
  required_plugins {
    tart = {
      version = "= 1.21.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_name" {
  type        = string
  description = "Name of the immutable local Tart image"
  default     = "vm-vpn-base"
}

source "tart-cli" "vpn_workspace" {
  vm_base_name = "ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"
  vm_name      = var.vm_name

  cpu_count    = 2
  memory_gb    = 6
  display      = "1440x900"
  communicator = "none"
}

build {
  sources = ["source.tart-cli.vpn_workspace"]
}
