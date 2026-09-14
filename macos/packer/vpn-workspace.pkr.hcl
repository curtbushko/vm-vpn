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

variable "display" {
  type        = string
  description = "Guest display resolution as WIDTHxHEIGHT; the build script sizes this to the host's main display."
  default     = "1440x900"
}

source "tart-cli" "vpn_workspace" {
  vm_base_name = "ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"
  vm_name      = var.vm_name

  cpu_count    = 2
  memory_gb    = 6
  display      = var.display
  communicator = "none"
}

build {
  sources = ["source.tart-cli.vpn_workspace"]
}
