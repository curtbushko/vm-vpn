#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	README="${REPO_ROOT}/README.md"
}

@test "README documents the complete placeholder command interface" {
	for command in identity init import-vpn import-bookmarks import-cert preflight materialize up down restart status rebuild diagnose cleanup share-add share-list share-remove; do
		grep -q "vm ${command} <product> <environment>" "${README}"
	done
	grep -q '^vm list$' "${README}"
	grep -q '^vm check$' "${README}"
	grep -q '^vm doctor$' "${README}"
}

@test "README documents host configuration settings and storage locations" {
	grep -Fq '~/.config/vm-vpn/<product>/<environment>/shares.json' "${README}"
	grep -Fq '~/.local/share/vm-vpn/<product>/<environment>/' "${README}"
	grep -Fq '~/.local/state/vm-vpn/<product>/<environment>/' "${README}"
	grep -Fq 'VM_VPN_CONFIG_HOME' "${README}"
	grep -Fq 'VM_VPN_DATA_HOME' "${README}"
	grep -Fq 'VM_VPN_STATE_HOME' "${README}"
	grep -Fq 'VM_VPN_INSTALLER_ISO' "${README}"
	grep -Fq 'VM_VPN_REPO_ROOT' "${README}"
	grep -Fq '"mode": "ro"' "${README}"
	grep -Fq '"mode": "rw"' "${README}"
}
