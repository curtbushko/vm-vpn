#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	PACKER_TEMPLATE="${REPO_ROOT}/macos/packer/vpn-workspace.pkr.hcl"
	INSTALL_SCRIPT="${REPO_ROOT}/macos/scripts/install-apps"
	CLEANUP_SCRIPT="${REPO_ROOT}/macos/scripts/cleanup-apps"
}

@test "macOS image uses the Tart Packer builder" {
	grep -Fq 'source  = "github.com/cirruslabs/tart"' "${PACKER_TEMPLATE}"
	grep -Fq 'vm_base_name = var.base_vm' "${PACKER_TEMPLATE}"
	grep -Fq 'scripts = [' "${PACKER_TEMPLATE}"
}

@test "macOS image installs Ghostty and Neovim" {
	grep -Fq 'brew install --cask ghostty' "${INSTALL_SCRIPT}"
	grep -Fq 'brew install neovim' "${INSTALL_SCRIPT}"
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

@test "macOS image tooling is supplied by the Nix development shell" {
	nix eval --raw "${REPO_ROOT}#devShells.aarch64-darwin.default.name" >/dev/null
	grep -A30 'devShells.*default' "${REPO_ROOT}/flake.nix" | grep -Fq 'darwinPkgs.packer'
}

@test "README documents Nix-driven macOS image builds" {
	grep -Fq 'nix develop -c packer init macos/packer' "${REPO_ROOT}/README.md"
	grep -Fq 'nix develop -c packer build' "${REPO_ROOT}/README.md"
	grep -Fq 'Ghostty' "${REPO_ROOT}/README.md"
	grep -Fq 'Neovim' "${REPO_ROOT}/README.md"
}
