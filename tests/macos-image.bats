#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	PACKER_TEMPLATE="${REPO_ROOT}/macos/packer/vpn-workspace.pkr.hcl"
	INSTALL_SCRIPT="${REPO_ROOT}/macos/scripts/install-apps"
	CLEANUP_SCRIPT="${REPO_ROOT}/macos/scripts/cleanup-apps"
	CONFIGURE_SCRIPT="${REPO_ROOT}/macos/scripts/configure-apps"
	BOOTSTRAP_SCRIPT="${REPO_ROOT}/macos/scripts/bootstrap-workspace"
	GUEST_AGENT_SCRIPT="${REPO_ROOT}/macos/scripts/install-guest-agent"
}

@test "cleanup uses the installed AWS VPN application path" {
	run grep -F '"/Applications/AWS VPN Client/AWS VPN Client.app"' "${CLEANUP_SCRIPT}"
	[ "$status" -eq 0 ]
}

@test "macOS image uses the Tart Packer builder" {
	grep -Fq 'source  = "github.com/cirruslabs/tart"' "${PACKER_TEMPLATE}"
	grep -Fq 'version = "= 1.21.0"' "${PACKER_TEMPLATE}"
	grep -Fq 'vm_base_name = "ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"' "${PACKER_TEMPLATE}"
	grep -Eq 'communicator[[:space:]]*=[[:space:]]*"none"' "${PACKER_TEMPLATE}"
	run grep -E 'ssh_username|ssh_password' "${PACKER_TEMPLATE}"
	[ "${status}" -ne 0 ]
	run grep -E 'from_ipsw|boot_command' "${PACKER_TEMPLATE}"
	[ "${status}" -ne 0 ]
}

@test "macOS image is an immutable compact vanilla clone" {
	grep -Fq 'macos-sequoia-vanilla:latest' "${PACKER_TEMPLATE}"
	grep -Eq 'cpu_count[[:space:]]*=[[:space:]]*2' "${PACKER_TEMPLATE}"
	grep -Eq 'memory_gb[[:space:]]*=[[:space:]]*6' "${PACKER_TEMPLATE}"
	run grep -E 'disk_format|disk_size_gb|recovery_partition' "${PACKER_TEMPLATE}"
	[ "${status}" -ne 0 ]
	grep -Fq 'bootstrap-guest-agent' "${REPO_ROOT}/macos/scripts/build-image"
	grep -Fq 'tart-guest-agent-darwin-all.tar.gz' "${GUEST_AGENT_SCRIPT}"
	grep -Fq 'org.openai.tart-guest-agent.plist' "${GUEST_AGENT_SCRIPT}"
	grep -Fq 'seal-image' "${REPO_ROOT}/macos/scripts/provision-vm"
}

@test "macOS build wrapper provisions and stops the Packer artifact" {
	build_script="${REPO_ROOT}/macos/scripts/build-image"
	grep -Fq 'packer build' "$build_script"
	grep -Fq 'macos/packer/vpn-workspace.pkr.hcl' "$build_script"
	grep -Fq 'tart get' "$build_script"
	grep -Fq 'tart run "$BUILD_VM_NAME" &' "$build_script"
	[ "$(grep -Fc 'tart run "$BUILD_VM_NAME" &' "$build_script")" -eq 2 ]
	grep -Fq 'tart exec "$BUILD_VM_NAME" sudo /sbin/shutdown -h now' "$build_script"
	grep -Fq 'tart exec -i "$BUILD_VM_NAME" /bin/bash -s <"${SCRIPT_DIR}/verify-image"' "$build_script"
	grep -Fq 'tart rename "$BUILD_VM_NAME" "$VM_NAME"' "$build_script"
	grep -Fq 'provision-vm' "$build_script"
	grep -Fq 'bootstrap-guest-agent' "$build_script"
	grep -Fq 'env VM_NAME="$BUILD_VM_NAME" "${SCRIPT_DIR}/bootstrap-guest-agent"' "$build_script"
	grep -Fq 'env VM_NAME="$BUILD_VM_NAME" "${SCRIPT_DIR}/provision-vm"' "$build_script"
	run grep -F 'VM_NAME="$BUILD_VM_NAME" "${SCRIPT_DIR}/bootstrap-guest-agent"' "$build_script"
	[ "$status" -eq 0 ]
	[[ "$output" == env\ * ]]
	grep -Fq 'verify-image' "${REPO_ROOT}/macos/scripts/provision-vm"
	grep -Fq 'install-apps configure-apps seal-image cleanup-apps verify-image' "${REPO_ROOT}/macos/scripts/provision-vm"
	grep -Fq 'tart exec' "${REPO_ROOT}/macos/scripts/provision-vm"
	grep -Fq 'sshpass -e /usr/bin/ssh -F /dev/null' "${REPO_ROOT}/macos/scripts/bootstrap-guest-agent"
	grep -Fq 'networksetup -setdnsservers Ethernet 1.1.1.1 8.8.8.8' "${REPO_ROOT}/macos/scripts/bootstrap-guest-agent"
}

@test "macOS image verification requires customized apps and Dock" {
	verify_script="${REPO_ROOT}/macos/scripts/verify-image"
	grep -Fq '/Applications/Firefox.app' "$verify_script"
	grep -Fq '/Applications/Ghostty.app' "$verify_script"
	grep -Fq '/Applications/AWS VPN Client/AWS VPN Client.app' "$verify_script"
	grep -Fq 'expected_dock_labels' "$verify_script"
	grep -Fq 'AWS VPN Client' "$verify_script"
	grep -Fq 'dockutil --list' "$verify_script"
	grep -Fq 'expected 3 Dock items' "$verify_script"
}

@test "macOS vanilla bootstrap installs the Tart agent before first shutdown" {
	grep -Fq 'tart-guest-agent-darwin-all.tar.gz' "${GUEST_AGENT_SCRIPT}"
	grep -Fq 'launchctl bootstrap "gui/$(id -u)"' "${GUEST_AGENT_SCRIPT}"
}

@test "macOS image installs only the required third-party applications" {
	grep -Fq 'brew install --cask firefox' "${INSTALL_SCRIPT}"
	grep -Fq 'brew install --cask ghostty' "${INSTALL_SCRIPT}"
	grep -Fq 'brew install --cask aws-vpn-client' "${INSTALL_SCRIPT}"
	grep -Fq '/usr/local/bin/aws-vpn-client' "${INSTALL_SCRIPT}"
	grep -Fq 'xattr -d com.apple.quarantine' "${INSTALL_SCRIPT}"
	run grep -F 'xattr -dr' "${INSTALL_SCRIPT}"
	[ "${status}" -ne 0 ]
	run grep -F -- '--no-quarantine' "${INSTALL_SCRIPT}"
	[ "${status}" -ne 0 ]
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
	grep -Fq 'AppleLanguages' "${CONFIGURE_SCRIPT}"
	grep -Fq 'AppleLocale' "${CONFIGURE_SCRIPT}"
	grep -Fq 'intl.locale.requested' "${CONFIGURE_SCRIPT}"
	grep -Fq 'LANG' "${CONFIGURE_SCRIPT}"
	grep -Fq -- '-CreateProfile vm-vpn' "${CONFIGURE_SCRIPT}"
}

@test "macOS bootstrap synchronizes mounted VPN profiles and bookmarks" {
	grep -Fq '/usr/local/bin/aws-vpn-client' "${BOOTSTRAP_SCRIPT}"
	grep -Fq '/Volumes/My Shared Files/workspace' "${BOOTSTRAP_SCRIPT}"
	grep -Fq 'vpn/*.ovpn' "${BOOTSTRAP_SCRIPT}"
	grep -Fq 'import-profile --profile-name "$profile_name"' "${BOOTSTRAP_SCRIPT}"
	grep -Fq 'delete-profile --profile-name "$profile_name"' "${BOOTSTRAP_SCRIPT}"
	grep -Fq 'ManagedBookmarks' "${BOOTSTRAP_SCRIPT}"
	grep -Fq 'com.vm-vpn.bootstrap.plist' "${CONFIGURE_SCRIPT}"
	grep -Fq 'StandardOutPath' "${CONFIGURE_SCRIPT}"
	grep -Fq 'vm-vpn-bootstrap.log' "${CONFIGURE_SCRIPT}"
	grep -Fq 'StandardErrorPath' "${CONFIGURE_SCRIPT}"
	grep -Fq 'vm-vpn-bootstrap.error.log' "${CONFIGURE_SCRIPT}"
	grep -Fq 'chown "$(id -u):$(id -g)" "${FIREFOX_POLICY_FILE}"' "${CONFIGURE_SCRIPT}"
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
	grep -Fq 'reduceMotion -bool true || true' "${seal_script}"
	grep -Fq 'reduceTransparency -bool true || true' "${seal_script}"
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
	run grep -F 'atsutil databases -removeUser' "${seal_script}"
	[ "${status}" -ne 0 ]
}

@test "macOS image tooling is supplied by the Nix development shell" {
	nix eval --raw "${REPO_ROOT}#devShells.aarch64-darwin.default.name" >/dev/null
	grep -A30 'devShells.*default' "${REPO_ROOT}/flake.nix" | grep -Fq 'packer'
	grep -Fq 'shellcheck macos/scripts/* scripts/ci-check scripts/vm' "${REPO_ROOT}/scripts/ci-check"
	grep -Fq 'shfmt -d macos/scripts/* scripts/ci-check scripts/vm' "${REPO_ROOT}/scripts/ci-check"
}

@test "flake patches Packer's vendored Apple CPU probe for M5" {
	grep -Fq 'darwinPkgs.packer.overrideAttrs' "${REPO_ROOT}/flake.nix"
	grep -Fq 'postConfigure' "${REPO_ROOT}/flake.nix"
	grep -Fq 'if (typeRef == NULL)' "${REPO_ROOT}/flake.nix"
}

@test "development shell inherits Darwin OpenSSH for Apple SSH options" {
	run grep -F 'darwinPkgs.openssh' "${REPO_ROOT}/flake.nix"
	[ "${status}" -ne 0 ]
	grep -Fq '/usr/bin/ssh' "${REPO_ROOT}/macos/scripts/bootstrap-guest-agent"
}

@test "flake contains no Linux image build outputs" {
	run grep -E 'nixosConfigurations|aarch64-linux|demo-dev-installer|aws-vpn-client' "${REPO_ROOT}/flake.nix"
	[ "${status}" -ne 0 ]
	grep -Fq 'devShells.${darwinSystem}.default' "${REPO_ROOT}/flake.nix"
}

@test "README documents the config-first workflow" {
	grep -Fq 'task setup' "${REPO_ROOT}/README.md"
	grep -Fq 'task create -- <product> <environment>' "${REPO_ROOT}/README.md"
	grep -Fq 'task delete -- <product> <environment>' "${REPO_ROOT}/README.md"
	grep -Fq 'task start -- <product> <environment>' "${REPO_ROOT}/README.md"
	grep -Fq 'task validate -- <product> <environment>' "${REPO_ROOT}/README.md"
	grep -Fq 'Firefox' "${REPO_ROOT}/README.md"
	grep -Fq 'Ghostty' "${REPO_ROOT}/README.md"
	grep -Fq 'AWS VPN Client' "${REPO_ROOT}/README.md"
	run grep -E 'NixOS|Hyprland|Neovim|installer ISO' "${REPO_ROOT}/README.md"
	[ "${status}" -ne 0 ]
	grep -Fq '50 GB raw disk' "${REPO_ROOT}/README.md"
}

@test "README documents clean-host and concurrent multi-VM workflow" {
	grep -Fq 'Apple Silicon Mac' "${REPO_ROOT}/README.md"
	grep -Fq 'Determinate Nix' "${REPO_ROOT}/README.md"
	grep -Fq 'install.determinate.systems/nix' "${REPO_ROOT}/README.md"
	grep -Fq 'direnv allow' "${REPO_ROOT}/README.md"
	grep -Fq '24 GB' "${REPO_ROOT}/README.md"
	grep -Fq '28 GB' "${REPO_ROOT}/README.md"
	grep -Fq 'Local Network' "${REPO_ROOT}/README.md"
	grep -Fq 'task create -- demo dev' "${REPO_ROOT}/README.md"
	grep -Fq 'task validate -- demo dev' "${REPO_ROOT}/README.md"
	grep -Fq 'task list' "${REPO_ROOT}/README.md"
	grep -Fq 'and clones are managed internally.' "${REPO_ROOT}/README.md"
	grep -Fq 'run concurrently' "${REPO_ROOT}/README.md"
	grep -Fq 'separate terminal' "${REPO_ROOT}/README.md"
	run grep -F 'nix develop -c' "${REPO_ROOT}/README.md"
	[ "${status}" -ne 0 ]
	grep -Fq 'fresh-machine acceptance run' "${REPO_ROOT}/README.md"
}

@test "README leads a new user from a fresh Mac to a visible demo" {
	readme="${REPO_ROOT}/README.md"
	grep -Fq '## Fresh-Mac quick start' "$readme"
	grep -Fq '## Returning-user workflow' "$readme"
	grep -Fq 'at least 65 GB of free disk space' "$readme"
	grep -Fq 'task setup' "$readme"
	grep -Fq 'task create -- demo dev' "$readme"
	grep -Fq 'task seed -- demo dev' "$readme"
	grep -Fq 'task validate -- demo dev' "$readme"
	grep -Fq 'task start -- demo dev' "$readme"
	grep -Fq 'demo VPN profile is intentionally non-functional' "$readme"

	fresh_line="$(grep -n -F '## Fresh-Mac quick start' "$readme" | cut -d: -f1)"
	setup_line="$(grep -n -m1 -F 'task setup' "$readme" | cut -d: -f1)"
	returning_line="$(grep -n -F '## Returning-user workflow' "$readme" | cut -d: -f1)"
	config_line="$(grep -n -F '## Config locations and format' "$readme" | cut -d: -f1)"
	[ "$fresh_line" -lt "$setup_line" ]
	[ "$setup_line" -lt "$returning_line" ]
	[ "$returning_line" -lt "$config_line" ]
}
