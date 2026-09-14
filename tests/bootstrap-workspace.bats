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
	export VM_VPN_SHARED_ROOT="${BATS_TEST_TMPDIR}/shared"
	export HOME="${BATS_TEST_TMPDIR}/home"
	mkdir -p "${HOME}" "${VM_VPN_SHARED_ROOT}"
	export VM_VPN_PKILL="${BATS_TEST_TMPDIR}/bin/pkill"
	export VM_VPN_SUDO="${BATS_TEST_TMPDIR}/bin/sudo"
	export VM_VPN_SCUTIL="${BATS_TEST_TMPDIR}/bin/scutil"
	export VM_VPN_HOSTS_FILE="${BATS_TEST_TMPDIR}/etc-hosts"
	export SCUTIL_LOG="${BATS_TEST_TMPDIR}/scutil.log"
	export PKILL_LOG="${BATS_TEST_TMPDIR}/pkill.log"
	export APPEARANCE_LOG="${BATS_TEST_TMPDIR}/appearance.log"
	mkdir -p "${BATS_TEST_TMPDIR}/bin" "${VM_VPN_WORKSPACE_ROOT}/vpn" "$(dirname "${VM_VPN_FIREFOX_POLICY_FILE}")"
	cat >"${VM_VPN_PKILL}" <<'EOF'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >>"${PKILL_LOG}"
EOF
	chmod 0755 "${VM_VPN_PKILL}"
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
	cat >"${VM_VPN_SCUTIL}" <<'EOF'
#!/usr/bin/env bash
printf 'scutil %s\n' "$*" >>"${SCUTIL_LOG}"
EOF
	cat >"${VM_VPN_SUDO}" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-n" ]]; then
  shift
fi
exec "$@"
EOF
	chmod 0755 "${VM_VPN_SCUTIL}" "${VM_VPN_SUDO}"
}

@test "runtime bootstrap applies the generated wallpaper through System Events" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
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

@test "runtime bootstrap quits Firefox only when bookmarks change" {
	printf '[{"title":"Development","url":"https://developer.mozilla.org/"}]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'pkill -x firefox' "${PKILL_LOG}"

	: >"${PKILL_LOG}"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	[ ! -s "${PKILL_LOG}" ]

	printf '[{"title":"Production","url":"https://docs.aws.amazon.com/vpn/"}]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'pkill -x firefox' "${PKILL_LOG}"
}

@test "runtime bootstrap announces the permissions prompt on first boot only" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	printf '%s\n' "${output}" | grep -Fq 'first boot: accept the macOS permissions prompts'

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	run bash -c 'printf "%s\n" "$1" | grep -Fq "first boot"' _ "${output}"
	[ "${status}" -ne 0 ]
}

@test "runtime bootstrap quits AWS VPN Client only when profiles change" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
	printf 'remote dev.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/development.ovpn"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'pkill -x AWS VPN Client' "${PKILL_LOG}"

	: >"${PKILL_LOG}"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	run grep -Fq 'AWS VPN Client' "${PKILL_LOG}"
	[ "${status}" -ne 0 ]

	printf 'remote prod.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/development.ovpn"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'pkill -x AWS VPN Client' "${PKILL_LOG}"
}

@test "runtime bootstrap applies bookmarks before requesting wallpaper automation" {
	bookmark_line="$(grep -n 'workspace_bookmarks' "${BOOTSTRAP_SCRIPT}" | tail -n 1 | cut -d: -f1)"
	appearance_line="$(grep -n '^[[:space:]]*"$OSASCRIPT" ' "${BOOTSTRAP_SCRIPT}" | cut -d: -f1)"
	[ "$bookmark_line" -lt "$appearance_line" ]
	grep -Fq 'tell application "System Events"' "${BOOTSTRAP_SCRIPT}"
	run grep -E 'com\.apple\.desktop|WallpaperAgent' "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -ne 0 ]
}

@test "runtime bootstrap sets the guest hostname to the vm name" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
	printf 'vm-vpn-demo-dev\n' >"${VM_VPN_WORKSPACE_ROOT}/.vm-name"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'scutil --set HostName vm-vpn-demo-dev' "${SCUTIL_LOG}"
	grep -Fq 'scutil --set LocalHostName vm-vpn-demo-dev' "${SCUTIL_LOG}"
	grep -Fq 'scutil --set ComputerName vm-vpn-demo-dev' "${SCUTIL_LOG}"

	: >"${SCUTIL_LOG}"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	[ ! -s "${SCUTIL_LOG}" ]

	printf 'vm-vpn-demo-prod\n' >"${VM_VPN_WORKSPACE_ROOT}/.vm-name"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq 'scutil --set HostName vm-vpn-demo-prod' "${SCUTIL_LOG}"
}

@test "runtime bootstrap rejects an invalid vm name" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
	printf 'not; a; hostname\n' >"${VM_VPN_WORKSPACE_ROOT}/.vm-name"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -ne 0 ]
	printf '%s\n' "${output}" | grep -Fq 'invalid vm name'
}

@test "runtime bootstrap creates symlinks for mounts.json entries with a link" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
	mkdir -p "${VM_VPN_SHARED_ROOT}/code" "${VM_VPN_SHARED_ROOT}/reference"
	cat >"${VM_VPN_WORKSPACE_ROOT}/mounts.json" <<EOF
[
  { "tag": "code", "source": "/host/workspace", "link": "~/code" },
  { "tag": "reference", "source": "/opt/reference", "link": "${HOME}/refs/data", "readonly": true }
]
EOF

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	[ -L "${HOME}/code" ]
	[ "$(readlink "${HOME}/code")" = "${VM_VPN_SHARED_ROOT}/code" ]
	[ -L "${HOME}/refs/data" ]
	[ "$(readlink "${HOME}/refs/data")" = "${VM_VPN_SHARED_ROOT}/reference" ]
}

@test "runtime bootstrap refreshes stale mount symlinks and refuses to clobber real paths" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
	mkdir -p "${VM_VPN_SHARED_ROOT}/code"
	ln -s /nonexistent "${HOME}/code"
	cat >"${VM_VPN_WORKSPACE_ROOT}/mounts.json" <<EOF
[ { "tag": "code", "source": "/host/workspace", "link": "~/code" } ]
EOF

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	[ "$(readlink "${HOME}/code")" = "${VM_VPN_SHARED_ROOT}/code" ]

	rm "${HOME}/code"
	mkdir -p "${HOME}/code"
	touch "${HOME}/code/keep.txt"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -ne 0 ]
	printf '%s\n' "${output}" | grep -Fq "refusing to replace existing path"
	[ -f "${HOME}/code/keep.txt" ]
}

@test "runtime bootstrap writes hosts.json entries into /etc/hosts idempotently" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
	printf '127.0.0.1 localhost\n' >"${VM_VPN_HOSTS_FILE}"
	cat >"${VM_VPN_WORKSPACE_ROOT}/hosts.json" <<'EOF'
[
  { "ip": "10.0.0.5", "hostnames": ["api.internal", "api"] },
  { "ip": "10.0.0.6", "hostnames": ["db.internal"] }
]
EOF

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq '# BEGIN vm-vpn hosts' "${VM_VPN_HOSTS_FILE}"
	grep -Fq '10.0.0.5 api.internal api' "${VM_VPN_HOSTS_FILE}"
	grep -Fq '10.0.0.6 db.internal' "${VM_VPN_HOSTS_FILE}"
	grep -Fq '# END vm-vpn hosts' "${VM_VPN_HOSTS_FILE}"
	grep -Fq '127.0.0.1 localhost' "${VM_VPN_HOSTS_FILE}"

	before_sum="$(shasum -a 256 "${VM_VPN_HOSTS_FILE}" | awk '{print $1}')"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	[ "$(shasum -a 256 "${VM_VPN_HOSTS_FILE}" | awk '{print $1}')" = "$before_sum" ]

	cat >"${VM_VPN_WORKSPACE_ROOT}/hosts.json" <<'EOF'
[ { "ip": "10.0.0.7", "hostnames": ["cache.internal"] } ]
EOF
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq '10.0.0.7 cache.internal' "${VM_VPN_HOSTS_FILE}"
	run grep -Fq '10.0.0.5 api.internal api' "${VM_VPN_HOSTS_FILE}"
	[ "${status}" -ne 0 ]

	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/hosts.json"
	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	run grep -Fq '# BEGIN vm-vpn hosts' "${VM_VPN_HOSTS_FILE}"
	[ "${status}" -ne 0 ]
	grep -Fq '127.0.0.1 localhost' "${VM_VPN_HOSTS_FILE}"
}

@test "runtime bootstrap rejects an invalid hosts.json" {
	printf '[]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"
	printf '127.0.0.1 localhost\n' >"${VM_VPN_HOSTS_FILE}"
	printf '[{"ip":"not-an-ip","hostnames":["ok"]}]\n' >"${VM_VPN_WORKSPACE_ROOT}/hosts.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -ne 0 ]
	printf '%s\n' "${output}" | grep -Fq 'hosts.json is malformed'
}

@test "runtime bootstrap replaces VPN and bookmark configuration between starts" {
	printf 'remote dev.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/development.ovpn"
	printf 'remote staging.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/staging.ovpn"
	printf '[{"title":"Development","url":"https://developer.mozilla.org/"}]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"

	run "${BOOTSTRAP_SCRIPT}"
	[ "${status}" -eq 0 ]
	grep -Fq "import-profile --profile-name development --config-path ${VM_VPN_WORKSPACE_ROOT}/vpn/development.ovpn" "${AWS_VPN_CLIENT_LOG}"
	grep -Fq "import-profile --profile-name staging --config-path ${VM_VPN_WORKSPACE_ROOT}/vpn/staging.ovpn" "${AWS_VPN_CLIENT_LOG}"
	[ "$(jq -r '.policies.ManagedBookmarks[1].name' "${VM_VPN_FIREFOX_POLICY_FILE}")" = "Development" ]

	mv "${VM_VPN_WORKSPACE_ROOT}/vpn/development.ovpn" "${VM_VPN_WORKSPACE_ROOT}/vpn/production.ovpn"
	printf 'remote prod.example.com 443\n' >"${VM_VPN_WORKSPACE_ROOT}/vpn/production.ovpn"
	printf '[{"title":"Production","url":"https://docs.aws.amazon.com/vpn/"}]\n' >"${VM_VPN_WORKSPACE_ROOT}/bookmarks.json"

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
