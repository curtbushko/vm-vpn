#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	BOOTSTRAP_SCRIPT="${REPO_ROOT}/macos/scripts/bootstrap-workspace"
	export VM_VPN_WORKSPACE_ROOT="${BATS_TEST_TMPDIR}/workspace"
	export VM_VPN_AWS_VPN_CLIENT="${BATS_TEST_TMPDIR}/bin/aws-vpn-client"
	export AWS_VPN_CLIENT_LOG="${BATS_TEST_TMPDIR}/aws-vpn-client.log"
	export VM_VPN_FIREFOX_POLICY_FILE="${BATS_TEST_TMPDIR}/guest/policies.json"
	export VM_VPN_STATE_ROOT="${BATS_TEST_TMPDIR}/guest/state"
	export VM_VPN_WALLPAPER_FILE="${BATS_TEST_TMPDIR}/guest/wallpaper.png"
	export VM_VPN_SIPS="${BATS_TEST_TMPDIR}/bin/sips"
	export VM_VPN_OSASCRIPT="${BATS_TEST_TMPDIR}/bin/osascript"
	export APPEARANCE_LOG="${BATS_TEST_TMPDIR}/appearance.log"
	mkdir -p "${BATS_TEST_TMPDIR}/bin" "${VM_VPN_WORKSPACE_ROOT}/vpn" "${VM_VPN_WORKSPACE_ROOT}/bookmarks" "$(dirname "${VM_VPN_FIREFOX_POLICY_FILE}")"
	printf '{"policies":{"DisplayBookmarksToolbar":"always"}}\n' >"${VM_VPN_FIREFOX_POLICY_FILE}"
	cat >"${VM_VPN_AWS_VPN_CLIENT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${AWS_VPN_CLIENT_LOG}"
EOF
	chmod 0755 "${VM_VPN_AWS_VPN_CLIENT}"
	cat >"${VM_VPN_SIPS}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sips %s\n' "$*" >>"${APPEARANCE_LOG}"
output="${*: -1}"
printf 'png\n' >"$output"
EOF
	cat >"${VM_VPN_OSASCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'osascript %s\n' "$*" >>"${APPEARANCE_LOG}"
EOF
	chmod 0755 "${VM_VPN_SIPS}" "${VM_VPN_OSASCRIPT}"
}

@test "runtime bootstrap applies the generated wallpaper through System Events" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks/bookmarks.json"
	printf '{"wallpaperColor":"#D97706"}\n' >"${VM_VPN_WORKSPACE_ROOT}/appearance.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'sips -s format png' "${APPEARANCE_LOG}"
	grep -Fq "osascript - ${VM_VPN_WALLPAPER_FILE}" "${APPEARANCE_LOG}"
	[ -f "${VM_VPN_WALLPAPER_FILE}" ]

	: >"${APPEARANCE_LOG}"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	[ ! -s "${APPEARANCE_LOG}" ]

	printf '{"wallpaperColor":"#B91C1C"}\n' >"${VM_VPN_WORKSPACE_ROOT}/appearance.json"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'sips -s format png' "${APPEARANCE_LOG}"
}

@test "runtime bootstrap applies bookmarks before requesting wallpaper automation" {
	bookmark_line="$(grep -n 'workspace_bookmarks' "${BOOTSTRAP_SCRIPT}" | tail -n 1 | cut -d: -f1)"
	appearance_line="$(grep -n '^[[:space:]]*"$OSASCRIPT" ' "${BOOTSTRAP_SCRIPT}" | cut -d: -f1)"
	[ "$bookmark_line" -lt "$appearance_line" ]
	grep -Fq 'tell application "System Events"' "${BOOTSTRAP_SCRIPT}"
	run grep -E 'com\.apple\.desktop|WallpaperAgent' "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -ne 0 ]
}

@test "runtime bootstrap replaces VPN and bookmark configuration between starts" {
	printf 'remote dev.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/development.ovpn"
	printf 'remote staging.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/staging.ovpn"
	printf '[{"title":"Development","url":"https://developer.mozilla.org/"}]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks/bookmarks.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq "import-profile --profile-name development --config-path ${VM_VPN_WORKSPACE_ROOT}/vpn/development.ovpn" "${AWS_VPN_CLIENT_LOG}"
	grep -Fq "import-profile --profile-name staging --config-path ${VM_VPN_WORKSPACE_ROOT}/vpn/staging.ovpn" "${AWS_VPN_CLIENT_LOG}"
	[ "$(jq -r '.policies.ManagedBookmarks[1].name' "${VM_VPN_FIREFOX_POLICY_FILE}")" = "Development" ]

	mv "${VM_VPN_WORKSPACE_ROOT}/vpn/development.ovpn" "${VM_VPN_WORKSPACE_ROOT}/vpn/production.ovpn"
	printf 'remote prod.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/production.ovpn"
	printf '[{"title":"Production","url":"https://docs.aws.amazon.com/vpn/"}]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks/bookmarks.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'delete-profile --profile-name development' "${AWS_VPN_CLIENT_LOG}"
	grep -Fq 'delete-profile --profile-name staging' "${AWS_VPN_CLIENT_LOG}"
	grep -Fq "import-profile --profile-name production --config-path ${VM_VPN_WORKSPACE_ROOT}/vpn/production.ovpn" "${AWS_VPN_CLIENT_LOG}"
	[ "$(grep -Fc 'import-profile --profile-name staging' "${AWS_VPN_CLIENT_LOG}")" -eq 2 ]
	[ "$(jq -r '.policies.ManagedBookmarks[1].name' "${VM_VPN_FIREFOX_POLICY_FILE}")" = "Production" ]
	run jq -e '.policies.ManagedBookmarks[] | select(.name == "Development")' "${VM_VPN_FIREFOX_POLICY_FILE}"
	[ "${status}" -ne 0 ]

	command_count="$(wc -l <"${AWS_VPN_CLIENT_LOG}" | tr -d ' ')"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	[ "$(wc -l <"${AWS_VPN_CLIENT_LOG}" | tr -d ' ')" -eq "$command_count" ]
}
