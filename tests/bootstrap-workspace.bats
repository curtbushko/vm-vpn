#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	BOOTSTRAP_SCRIPT="${REPO_ROOT}/macos/scripts/bootstrap-workspace"
	export VM_VPN_WORKSPACE_ROOT="${BATS_TEST_TMPDIR}/workspace"
	export VM_VPN_VPN_DESTINATION="${BATS_TEST_TMPDIR}/guest/OpenVpnConfigs/workspace.ovpn"
	export VM_VPN_FIREFOX_POLICY_FILE="${BATS_TEST_TMPDIR}/guest/policies.json"
	export VM_VPN_STATE_ROOT="${BATS_TEST_TMPDIR}/guest/state"
	mkdir -p "${VM_VPN_WORKSPACE_ROOT}/vpn" "${VM_VPN_WORKSPACE_ROOT}/bookmarks" "$(dirname "${VM_VPN_FIREFOX_POLICY_FILE}")"
	printf '{"policies":{"DisplayBookmarksToolbar":"always"}}\n' >"${VM_VPN_FIREFOX_POLICY_FILE}"
}

@test "runtime bootstrap replaces VPN and bookmark configuration between starts" {
	printf 'remote dev.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/profile.ovpn"
	printf '[{"title":"Development","url":"https://developer.mozilla.org/"}]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks/bookmarks.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'dev.example.com' "${VM_VPN_VPN_DESTINATION}"
	[ "$(jq -r '.policies.ManagedBookmarks[1].name' "${VM_VPN_FIREFOX_POLICY_FILE}")" = "Development" ]

	printf 'remote prod.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/profile.ovpn"
	printf '[{"title":"Production","url":"https://docs.aws.amazon.com/vpn/"}]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks/bookmarks.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'prod.example.com' "${VM_VPN_VPN_DESTINATION}"
	run grep -F 'dev.example.com' "${VM_VPN_VPN_DESTINATION}"
	[ "${status}" -ne 0 ]
	[ "$(jq -r '.policies.ManagedBookmarks[1].name' "${VM_VPN_FIREFOX_POLICY_FILE}")" = "Production" ]
	run jq -e '.policies.ManagedBookmarks[] | select(.name == "Development")' "${VM_VPN_FIREFOX_POLICY_FILE}"
	[ "${status}" -ne 0 ]
}
