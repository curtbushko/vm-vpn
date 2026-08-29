packer {
  required_plugins {
    tart = {
      version = "= 1.16.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_name" {
  type        = string
  description = "Name of the immutable local Tart image"
  default     = "vm-vpn-macos-compact"
}

source "tart-cli" "vpn_workspace" {
  from_ipsw = "https://updates.cdn-apple.com/2025SummerFCS/fullrestores/093-10809/CFD6DD38-DAF0-40DA-854F-31AAD1294C6F/UniversalMac_15.6.1_24G90_Restore.ipsw"
  vm_name   = var.vm_name

  cpu_count          = 2
  memory_gb          = 6
  disk_size_gb       = 30
  disk_format        = "asif"
  display            = "1440x900"
  recovery_partition = "delete"
  create_grace_time  = "30s"
  communicator       = "none"

  boot_command = [
    "<wait60s><spacebar>",
    "<wait30s>italiano<esc>english<enter>",
    "<wait30s><click 'Select Your Country or Region'><wait5s>united states<leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait 'Transfer Your Data to This Mac'><tab><tab><tab><spacebar><tab><tab><spacebar>",
    "<wait 'Written and Spoken Languages'><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait 'Accessibility'><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait 'Data & Privacy'><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait 'Create a Mac Account'>Managed via Tart<tab>admin<tab>admin<tab>admin<tab><tab><spacebar><tab><tab><spacebar>",
    "<wait120s><leftAltOn><f5><leftAltOff>",
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait10s><tab><spacebar>",
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait10s><tab><spacebar>",
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait10s><tab><spacebar>",
    "<wait10s><tab><tab>UTC<enter><leftShiftOn><tab><tab><leftShiftOff><spacebar>",
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait10s><tab><spacebar>",
    "<wait10s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
    "<wait10s><tab><spacebar>",
    "<wait 'Welcome to Mac'><spacebar>",
    "<leftAltOn><f5><leftAltOff>",
    "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
    "<wait10s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",
    "<wait10s><leftAltOn>q<leftAltOff>",
    "<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",
    "<wait10s><leftCtrlOn><f2><leftCtrlOff><right><right><right><down>Sharing<enter>",
    "<wait10s><tab><tab><tab><tab><tab><tab><tab><spacebar>",
    "<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",
    "<wait10s><leftAltOn>q<leftAltOff>",
    "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
    "<wait10s>echo admin | sudo -S systemsetup -setsleep Off; curl -fsSL https://github.com/openai/tart-guest-agent/releases/download/v0.14.1/tart-guest-agent-darwin-all.tar.gz | tar -xz -C /tmp; echo admin | sudo -S install -d -m 0755 /usr/local/bin; echo admin | sudo -S install -m 0755 /tmp/tart-guest-agent /usr/local/bin/tart-guest-agent; mkdir -p ~/Library/LaunchAgents; echo PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz48IURPQ1RZUEUgcGxpc3QgUFVCTElDICItLy9BcHBsZS8vRFREIFBMSVNUIDEuMC8vRU4iICJodHRwOi8vd3d3LmFwcGxlLmNvbS9EVERzL1Byb3BlcnR5TGlzdC0xLjAuZHRkIj48cGxpc3QgdmVyc2lvbj0iMS4wIj48ZGljdD48a2V5PkxhYmVsPC9rZXk+PHN0cmluZz5vcmcub3BlbmFpLnRhcnQtZ3Vlc3QtYWdlbnQ8L3N0cmluZz48a2V5PlByb2dyYW1Bcmd1bWVudHM8L2tleT48YXJyYXk+PHN0cmluZz4vdXNyL2xvY2FsL2Jpbi90YXJ0LWd1ZXN0LWFnZW50PC9zdHJpbmc+PHN0cmluZz4tLXJ1bi1hZ2VudDwvc3RyaW5nPjwvYXJyYXk+PGtleT5SdW5BdExvYWQ8L2tleT48dHJ1ZS8+PGtleT5LZWVwQWxpdmU8L2tleT48dHJ1ZS8+PC9kaWN0PjwvcGxpc3Q+ | base64 -D > ~/Library/LaunchAgents/org.openai.tart-guest-agent.plist; chmod 0600 ~/Library/LaunchAgents/org.openai.tart-guest-agent.plist; launchctl bootstrap gui/501 ~/Library/LaunchAgents/org.openai.tart-guest-agent.plist<enter><wait180s>",
    "<wait10s><leftAltOn>q<leftAltOff>",
  ]
}

build {
  sources = ["source.tart-cli.vpn_workspace"]
}
