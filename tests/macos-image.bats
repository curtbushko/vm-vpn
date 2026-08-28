#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	PACKER_TEMPLATE="${REPO_ROOT}/macos/packer/vpn-workspace.pkr.hcl"
	INSTALL_SCRIPT="${REPO_ROOT}/macos/scripts/install-apps"
	CLEANUP_SCRIPT="${REPO_ROOT}/macos/scripts/cleanup-apps"
	CONFIGURE_SCRIPT="${REPO_ROOT}/macos/scripts/configure-apps"
	BOOTSTRAP_SCRIPT="${REPO_ROOT}/macos/scripts/bootstrap-workspace"
}

@test "macOS image uses the Tart Packer builder" {
	grep -Fq 'source  = "github.com/cirruslabs/tart"' "${PACKER_TEMPLATE}"
	grep -Fq 'version = "= 1.16.0"' "${PACKER_TEMPLATE}"
	grep -Fq 'vm_base_name = var.base_vm' "${PACKER_TEMPLATE}"
	grep -Fq 'communicator = "none"' "${PACKER_TEMPLATE}"
	run grep -F 'provisioner' "${PACKER_TEMPLATE}"
	[ "${status}" -ne 0 ]
}

@test "macOS build wrapper provisions and stops the Packer artifact" {
	build_script="${REPO_ROOT}/macos/scripts/build-image"
	grep -Fq 'packer build' "$build_script"
	grep -Fq 'provision-vm' "$build_script"
	grep -Fq 'tart stop' "$build_script"
	grep -Fq 'export VM_NAME' "$build_script"
}

@test "macOS image installs Ghostty and Neovim" {
	grep -Fq 'brew install --cask ghostty' "${INSTALL_SCRIPT}"
	grep -Fq 'brew install --cask aws-vpn-client' "${INSTALL_SCRIPT}"
	grep -Fq 'brew install neovim' "${INSTALL_SCRIPT}"
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
	grep -Fq 'vim.opt.background = "dark"' "${CONFIGURE_SCRIPT}"
	grep -Fq 'DisplayBookmarksToolbar' "${CONFIGURE_SCRIPT}"
	grep -Fq 'bitwarden-password-manager' "${CONFIGURE_SCRIPT}"
	grep -Fq '1password-x-password-manager' "${CONFIGURE_SCRIPT}"
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
}

@test "macOS cleanup removes inherited formulae and download caches" {
	grep -Eq 'dockutil[[:space:]]*[|][[:space:]]*jq[[:space:]]*[|][[:space:]]*neovim[[:space:]]*[|][[:space:]]*tart-guest-agent' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew uninstall --formula --force' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew autoremove' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew cleanup --prune=all' "${CLEANUP_SCRIPT}"
	grep -Fq '*/tart-guest-agent' "${CLEANUP_SCRIPT}"
	grep -Fq 'brew untap --force' "${CLEANUP_SCRIPT}"
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
