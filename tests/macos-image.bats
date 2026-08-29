#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	PACKER_TEMPLATE="${REPO_ROOT}/macos/packer/vpn-workspace.pkr.hcl"
	INSTALL_SCRIPT="${REPO_ROOT}/macos/scripts/install-apps"
	CLEANUP_SCRIPT="${REPO_ROOT}/macos/scripts/cleanup-apps"
	CONFIGURE_SCRIPT="${REPO_ROOT}/macos/scripts/configure-apps"
	BOOTSTRAP_SCRIPT="${REPO_ROOT}/macos/scripts/bootstrap-workspace"
}

@test "cleanup uses the installed AWS VPN application path" {
	run grep -F '"/Applications/AWS VPN Client/AWS VPN Client.app"' "${CLEANUP_SCRIPT}"
	[ "$status" -eq 0 ]
}

@test "macOS image uses the Tart Packer builder" {
	grep -Fq 'source  = "github.com/cirruslabs/tart"' "${PACKER_TEMPLATE}"
	grep -Fq 'version = "= 1.16.0"' "${PACKER_TEMPLATE}"
	grep -Fq 'from_ipsw' "${PACKER_TEMPLATE}"
	grep -Eq 'communicator[[:space:]]*=[[:space:]]*"none"' "${PACKER_TEMPLATE}"
}

@test "macOS image is an immutable compact ASIF installation" {
	grep -Fq 'from_ipsw' "${PACKER_TEMPLATE}"
	grep -Fq 'cpu_count          = 2' "${PACKER_TEMPLATE}"
	grep -Fq 'memory_gb          = 6' "${PACKER_TEMPLATE}"
	grep -Fq 'disk_size_gb       = 30' "${PACKER_TEMPLATE}"
	grep -Fq 'disk_format        = "asif"' "${PACKER_TEMPLATE}"
	grep -Fq 'recovery_partition = "delete"' "${PACKER_TEMPLATE}"
	grep -Fq 'systemsetup -setsleep Off' "${PACKER_TEMPLATE}"
	grep -Fq "<wait 'Create a Mac Account'>" "${PACKER_TEMPLATE}"
	grep -Fq "<wait 'Welcome to Mac'>" "${PACKER_TEMPLATE}"
	grep -Fq 'tart-guest-agent-darwin-all.tar.gz' "${PACKER_TEMPLATE}"
	grep -Fq 'org.openai.tart-guest-agent.plist' "${PACKER_TEMPLATE}"
	grep -Fq 'seal-image' "${REPO_ROOT}/macos/scripts/provision-vm"
	run grep -F 'vm_base_name' "${PACKER_TEMPLATE}"
	[ "${status}" -ne 0 ]
}

@test "macOS build wrapper provisions and stops the Packer artifact" {
	build_script="${REPO_ROOT}/macos/scripts/build-image"
	grep -Fq 'packer build' "$build_script"
	grep -Fq 'macos/packer/vpn-workspace.pkr.hcl' "$build_script"
	grep -Fq 'tart get' "$build_script"
	grep -Fq 'tart run "$VM_NAME" &' "$build_script"
	grep -Fq 'provision-vm' "$build_script"
	grep -Fq 'tart exec' "${REPO_ROOT}/macos/scripts/provision-vm"
}

@test "macOS IPSW bootstrap installs the Tart agent before first shutdown" {
	grep -Fq 'tart-guest-agent-darwin-all.tar.gz' "${PACKER_TEMPLATE}"
	grep -Fq 'launchctl bootstrap gui/501' "${PACKER_TEMPLATE}"
	grep -Fq 'base64 -D' "${PACKER_TEMPLATE}"
}

@test "macOS image installs only the required third-party applications" {
	grep -Fq 'brew install --cask ghostty' "${INSTALL_SCRIPT}"
	grep -Fq 'brew install --cask aws-vpn-client' "${INSTALL_SCRIPT}"
	run grep -F 'brew install neovim' "${INSTALL_SCRIPT}"
	[ "${status}" -ne 0 ]
	grep -Fq 'Homebrew/install/HEAD/install.sh' "${INSTALL_SCRIPT}"
	grep -Fq 'brew install openai/tools/tart-guest-agent' "${INSTALL_SCRIPT}"
	grep -Fq 'networksetup -setdnsservers Ethernet 1.1.1.1 8.8.8.8' "${INSTALL_SCRIPT}"
}

@test "macOS provisioning uses Tart guest execution instead of host networking" {
	grep -Fq 'tart exec -i' "${REPO_ROOT}/macos/scripts/provision-vm"
	run grep -E '/usr/bin/(ssh|scp)|sshpass' "${REPO_ROOT}/macos/scripts/provision-vm"
	[ "${status}" -ne 0 ]
}

@test "macOS applications receive workspace defaults" {
	grep -Fq 'Catppuccin Mocha' "${CONFIGURE_SCRIPT}"
	run grep -F 'vim.opt.background' "${CONFIGURE_SCRIPT}"
	[ "${status}" -ne 0 ]
	grep -Fq 'DisplayBookmarksToolbar' "${CONFIGURE_SCRIPT}"
	grep -Fq 'bitwarden-password-manager' "${CONFIGURE_SCRIPT}"
	grep -Fq '1password-x-password-manager' "${CONFIGURE_SCRIPT}"
	grep -Fq 'tart-guest-agent --run-agent' "${CONFIGURE_SCRIPT}"
}

@test "macOS bootstrap synchronizes mounted VPN profiles and bookmarks" {
	grep -Fq '.config/AWSVPNClient/OpenVpnConfigs' "${BOOTSTRAP_SCRIPT}"
	grep -Fq '/Volumes/My Shared Files/workspace' "${BOOTSTRAP_SCRIPT}"
	grep -Fq 'bookmarks.json' "${BOOTSTRAP_SCRIPT}"
	grep -Fq 'com.vm-vpn.bootstrap.plist' "${CONFIGURE_SCRIPT}"
}

@test "macOS cleanup preserves Safari and system protections" {
	grep -Fq 'Safari' "${CLEANUP_SCRIPT}"
	grep -Fq 'Calendar' "${CLEANUP_SCRIPT}"
	run grep -E 'csrutil|authenticated-root|/System/Applications/.+[^[:space:]]' "${CLEANUP_SCRIPT}"
	[ "${status}" -ne 0 ]
}

@test "macOS cleanup removes casks outside the minimal VPN workspace allowlist" {
	grep -Eq 'firefox[[:space:]]*[|][[:space:]]*ghostty[[:space:]]*[|][[:space:]]*aws-vpn-client' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew uninstall --cask --force' "${CLEANUP_SCRIPT}"
	run grep -F 'dock_apps' "${CLEANUP_SCRIPT}"
	[ "${status}" -eq 0 ]
	run grep -F '"/Applications/Safari.app"' "${CLEANUP_SCRIPT}"
	[ "${status}" -ne 0 ]
}

@test "macOS cleanup removes inherited formulae and download caches" {
	grep -Eq 'dockutil[[:space:]]*[|][[:space:]]*jq[[:space:]]*[|][[:space:]]*tart-guest-agent' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew uninstall --formula --force' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew autoremove' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew cleanup --prune=all' "${CLEANUP_SCRIPT}"
	grep -Fq '*/tart-guest-agent' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew untap --force' "${CLEANUP_SCRIPT}"
}

@test "macOS sealing disables storage-producing services and clears disposable state" {
	seal_script="${REPO_ROOT}/macos/scripts/seal-image"
	grep -Fq 'tmutil disable' "${seal_script}"
	grep -Fq 'AssetCacheManagerUtil deactivate' "${seal_script}"
	grep -Fq 'mdutil -a -i off' "${seal_script}"
	grep -Fq 'system/com.apple.softwareupdated' "${seal_script}"
	grep -Fq 'system/com.apple.mobile.softwareupdated' "${seal_script}"
	grep -Fq 'system/com.apple.mobileassetd' "${seal_script}"
	grep -Fq 'com.apple.notificationcenterui.agent' "${seal_script}"
	grep -Fq 'com.apple.usernotificationsd' "${seal_script}"
	grep -Fq 'com.apple.SoftwareUpdateNotificationManager' "${seal_script}"
	grep -Fq 'com.apple.locationd' "${seal_script}"
	grep -Fq 'LocationServicesEnabled' "${seal_script}"
	grep -Fq 'com.apple.Spotlight' "${seal_script}"
	grep -Fq 'com.apple.corespotlightd' "${seal_script}"
	grep -Fq 'com.apple.generativeexperiencesd' "${seal_script}"
	grep -Fq 'com.apple.intelligenceplatformd' "${seal_script}"
	grep -Fq 'com.apple.modelmanagerd' "${seal_script}"
	grep -Fq 'com.apple.siriinferenced' "${seal_script}"
	grep -Fq 'com.apple.photoanalysisd' "${seal_script}"
	grep -Fq 'com.apple.mediaanalysisd' "${seal_script}"
	grep -Fq 'com.apple.bird' "${seal_script}"
	grep -Fq 'com.apple.cloudd' "${seal_script}"
	grep -Fq 'com.apple.appstoreagent' "${seal_script}"
	grep -Fq 'com.apple.sharingd' "${seal_script}"
	grep -Fq 'com.apple.bluetoothd' "${seal_script}"
	grep -Fq 'com.apple.CalendarAgent' "${seal_script}"
	grep -Fq 'com.apple.ScreenTimeAgent' "${seal_script}"
	grep -Fq 'org.cups.cupsd' "${seal_script}"
	grep -Fq 'com.apple.backupd' "${seal_script}"
	grep -Fq 'com.apple.ReportCrash' "${seal_script}"
	grep -Fq 'NSAutomaticWindowAnimationsEnabled' "${seal_script}"
	grep -Fq 'reduceTransparency' "${seal_script}"
	grep -Fq 'StandardHideWidgets' "${seal_script}"
	grep -Fq 'CreateDesktop' "${seal_script}"
	grep -Fq 'Solid Colors/Black.png' "${seal_script}"
	grep -Fq 'pmset -a sleep 0' "${seal_script}"
	grep -Fq 'hibernatemode 0' "${seal_script}"
	grep -Fq 'com.apple.screensaver idleTime -int 0' "${seal_script}"
	grep -Fq 'com.apple.AirDropUI' "${seal_script}"
	grep -Fq 'com.apple.ensemble' "${seal_script}"
	grep -Fq 'com.apple.ImageCaptureExtension2' "${seal_script}"
	grep -Fq 'com.apple.MigrationAssistant' "${seal_script}"
	grep -Fq 'com.apple.ptpcamerad' "${seal_script}"
	grep -Fq 'AutomaticCheckEnabled' "${seal_script}"
	grep -Fq 'AutomaticDownload' "${seal_script}"
	grep -Fq 'AutomaticallyInstallMacOSUpdates' "${seal_script}"
	grep -Fq 'log erase --all' "${seal_script}"
	grep -Fq 'qlmanage -r cache' "${seal_script}"
	grep -Fq 'atsutil databases -removeUser' "${seal_script}"
}

@test "macOS image tooling is supplied by the Nix development shell" {
	nix eval --raw "${REPO_ROOT}#devShells.aarch64-darwin.default.name" >/dev/null
	grep -A30 'devShells.*default' "${REPO_ROOT}/flake.nix" | grep -Fq 'darwinPkgs.packer'
}

@test "README documents Nix-driven macOS image builds" {
	grep -Fq 'nix develop -c packer init macos/packer' "${REPO_ROOT}/README.md"
	grep -Fq 'nix develop -c macos/scripts/build-image' "${REPO_ROOT}/README.md"
	grep -Fq 'Ghostty' "${REPO_ROOT}/README.md"
	grep -Fq 'Neovim' "${REPO_ROOT}/README.md"
}
