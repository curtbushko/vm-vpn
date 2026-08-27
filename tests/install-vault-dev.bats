#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	INSTALL_COMMAND="${REPO_ROOT}/scripts/install-vault-dev"
}

@test "help documents required destructive arguments" {
	run "${INSTALL_COMMAND}" --help

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"--device DEVICE --repo PATH --yes"* ]]
}

@test "installation refuses to run without explicit confirmation" {
	run "${INSTALL_COMMAND}" --device /dev/vda --repo /mnt/repo

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"--yes is required"* ]]
}

@test "dry run shows the deterministic partition and install operations" {
	run "${INSTALL_COMMAND}" --device /dev/vda --repo /mnt/repo --dry-run

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"parted --script /dev/vda mklabel gpt"* ]]
	[[ "${output}" == *"mkfs.fat -F 32 -n ESP /dev/vda1"* ]]
	[[ "${output}" == *"mkfs.ext4 -F -L nixos /dev/vda2"* ]]
	[[ "${output}" == *"--extra-experimental-features"*"nix-command flakes"* ]]
	[[ "${output}" == *"nixos-install --root /mnt --system SYSTEM_PATH --no-root-password"* ]]
}

@test "installation rejects an unsafe device name" {
	run "${INSTALL_COMMAND}" --device /dev/disk0 --repo /mnt/repo --yes

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"virtio block device"* ]]
}

@test "resume skips destructive disk initialization" {
	run "${INSTALL_COMMAND}" --device /dev/vda --repo /mnt/repo --resume --dry-run

	[ "${status}" -eq 0 ]
	[[ "${output}" != *"parted"* ]]
	[[ "${output}" != *"mkfs"* ]]
	[[ "${output}" == *"nixos-install --root /mnt --system SYSTEM_PATH --no-root-password"* ]]
}
