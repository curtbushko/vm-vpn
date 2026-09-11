#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	VM_SCRIPT="${REPO_ROOT}/scripts/vm"
	export VM_VPN_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
	export VM_VPN_REPO_ROOT="${REPO_ROOT}"
	export VM_VPN_BUILD_SCRIPT="${BATS_TEST_TMPDIR}/build-image"
	export TART_LOG="${BATS_TEST_TMPDIR}/tart.log"
	export TART_INSTANCES="${BATS_TEST_TMPDIR}/instances"
	export VM_VPN_BASE_MARKER="${BATS_TEST_TMPDIR}/base-image-ready"
	export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
	mkdir -p "${BATS_TEST_TMPDIR}/bin"
	: >"${TART_INSTANCES}"
	printf 'verified:12\n' >"${VM_VPN_BASE_MARKER}"

	cat >"${BATS_TEST_TMPDIR}/bin/tart" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${TART_LOG}"
case "${1:-}" in
get)
	if [[ "${2:-}" == "vm-vpn-base" ]]; then
		[[ "${TART_BASE_MISSING:-0}" != "1" ]] || exit 1
	elif ! grep -Fxq "${2:-}" "${TART_INSTANCES}"; then
		exit 1
	fi
	printf 'OS CPU Memory Disk State\ndarwin 2 6144 50 stopped\n'
	;;
clone)
	printf '%s\n' "$3" >>"${TART_INSTANCES}"
	;;
delete)
	awk -v target="$2" '$0 != target' "${TART_INSTANCES}" >"${TART_INSTANCES}.next"
	mv "${TART_INSTANCES}.next" "${TART_INSTANCES}"
	;;
list)
	printf 'Source Name State\nlocal vm-vpn-base stopped\n'
	awk '{ printf "local %s stopped\n", $0 }' "${TART_INSTANCES}"
	;;
esac
EOF
	chmod 0755 "${BATS_TEST_TMPDIR}/bin/tart"

	cat >"${VM_VPN_BUILD_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"${TART_LOG}.build"
EOF
	chmod 0755 "${VM_VPN_BUILD_SCRIPT}"
}

@test "create initializes only a protected host configuration" {
	run "${VM_SCRIPT}" create demo dev
	[ "${status}" -eq 0 ]
	[ -d "${VM_VPN_CONFIG_HOME}/demo/dev/vpn" ]
	[ -d "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks" ]
	[ -d "${VM_VPN_CONFIG_HOME}/demo/dev/shared" ]
	[ "$(jq -r '.wallpaperColor' "${VM_VPN_CONFIG_HOME}/demo/dev/appearance.json")" = "#7895A8" ]
	[ "$(jq -r 'length' "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks/bookmarks.json")" -eq 2 ]
	[ "$(jq -r '.[0].title' "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks/bookmarks.json")" = "Company documentation" ]
	[ "$(jq -r '.[0].url' "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks/bookmarks.json")" = "https://docs.example.com/" ]
	[ "$(jq -r '.[1].title' "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks/bookmarks.json")" = "Service dashboard" ]
	[ "$(jq -r '.[1].url' "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks/bookmarks.json")" = "https://dashboard.example.com/" ]
	[ ! -s "${TART_LOG}" ]

	run "${VM_SCRIPT}" create demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"configuration already exists"* ]]
}

@test "create chooses a wallpaper color from the environment" {
	local environment expected_color
	while read -r environment expected_color; do
		"${VM_SCRIPT}" create demo "$environment"
		[ "$(jq -r '.wallpaperColor' "${VM_VPN_CONFIG_HOME}/demo/${environment}/appearance.json")" = "$expected_color" ]
	done <<'EOF'
dev #7895A8
staging #5F7F95
prod #465F70
hybridtest #B77A7A
preprod #965E5E
awsgov-prod #744747
qa #374151
EOF
}

@test "start migrates legacy generated colors without replacing custom colors" {
	"${VM_SCRIPT}" create demo staging
	printf '{"wallpaperColor":"#D97706"}\n' >"${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json"

	run "${VM_SCRIPT}" start demo staging
	[ "${status}" -eq 0 ]
	[ "$(jq -r '.wallpaperColor' "${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json")" = "#5F7F95" ]

	printf '{"wallpaperColor":"#2563EB"}\n' >"${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json"
	run "${VM_SCRIPT}" start demo staging
	[ "${status}" -eq 0 ]
	[ "$(jq -r '.wallpaperColor' "${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json")" = "#5F7F95" ]

	printf '{"wallpaperColor":"#ABCDEF"}\n' >"${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json"
	run "${VM_SCRIPT}" start demo staging
	[ "${status}" -eq 0 ]
	[ "$(jq -r '.wallpaperColor' "${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json")" = "#ABCDEF" ]
}

@test "start lazily creates and then reuses the hidden runtime clone" {
	"${VM_SCRIPT}" create demo dev

	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"config: demo/dev"* ]]
	[[ "${output}" == *"bookmarks: valid"* ]]
	[[ "${output}" == *"vpn profiles: 0"* ]]
	[[ "${output}" == *"runtime: creating from shared image"* ]]
	[[ "${output}" == *"bootstrap logs: task logs -- demo dev"* ]]
	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"runtime: reusing existing runtime"* ]]

	[ "$(grep -Fc 'clone vm-vpn-base vm-vpn-demo-dev' "${TART_LOG}")" -eq 1 ]
	[ "$(grep -Fc "run vm-vpn-demo-dev --dir workspace:${VM_VPN_CONFIG_HOME}/demo/dev" "${TART_LOG}")" -eq 2 ]
	run grep -F ":ro" "${TART_LOG}"
	[ "${status}" -ne 0 ]
}

@test "start migrates missing appearance and rejects invalid colors" {
	"${VM_SCRIPT}" create demo staging
	mv "${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json" "${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json.missing"

	run "${VM_SCRIPT}" start demo staging
	[ "${status}" -eq 0 ]
	[ "$(jq -r '.wallpaperColor' "${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json")" = "#5F7F95" ]
	[[ "${output}" == *"appearance: valid"* ]]

	printf '{"wallpaperColor":"orange"}\n' >"${VM_VPN_CONFIG_HOME}/demo/staging/appearance.json"
	run "${VM_SCRIPT}" start demo staging
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"appearance is invalid"* ]]
}

@test "start rejects a missing configuration or base image" {
	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"task create -- demo dev"* ]]

	"${VM_SCRIPT}" create demo dev
	export TART_BASE_MISSING=1
	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"task setup"* ]]
}

@test "logs streams the guest bootstrap output for a running config" {
	"${VM_SCRIPT}" create demo dev
	"${VM_SCRIPT}" start demo dev

	run "${VM_SCRIPT}" logs demo dev
	[ "${status}" -eq 0 ]
	grep -Fq 'exec vm-vpn-demo-dev /usr/bin/tail -n 200 -f /Users/admin/Library/Logs/vm-vpn-bootstrap.log /Users/admin/Library/Logs/vm-vpn-bootstrap.error.log' "${TART_LOG}"
}

@test "multiple configs start independent hidden VMs concurrently" {
	for environment in dev staging prod; do
		"${VM_SCRIPT}" create demo "${environment}"
		run "${VM_SCRIPT}" start demo "${environment}"
		[ "${status}" -eq 0 ]
	done
	"${VM_SCRIPT}" create internal-tools prod-east
	"${VM_SCRIPT}" start internal-tools prod-east

	grep -Fq 'clone vm-vpn-base vm-vpn-demo-dev' "${TART_LOG}"
	grep -Fq 'clone vm-vpn-base vm-vpn-demo-staging' "${TART_LOG}"
	grep -Fq 'clone vm-vpn-base vm-vpn-demo-prod' "${TART_LOG}"
	grep -Fq 'clone vm-vpn-base vm-vpn-internal_tools-prod_east' "${TART_LOG}"
}

@test "validate reports bookmark and VPN readiness" {
	"${VM_SCRIPT}" create demo dev

	run "${VM_SCRIPT}" validate demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"bookmarks: valid"* ]]
	[[ "${output}" == *"vpn: missing"* ]]

	printf 'client\nremote dev.example.com 443\n' >"${VM_VPN_CONFIG_HOME}/demo/dev/vpn/development.ovpn"
	printf 'client\nremote prod.example.com 443\n' >"${VM_VPN_CONFIG_HOME}/demo/dev/vpn/production.ovpn"
	run "${VM_SCRIPT}" validate demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"vpn: present"* ]]
}

@test "list and status describe configs without exposing VM names" {
	"${VM_SCRIPT}" create demo dev
	"${VM_SCRIPT}" create demo prod
	"${VM_SCRIPT}" start demo dev

	run "${VM_SCRIPT}" list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *$'CONFIG\tSTATE\tVPN\tBOOKMARKS'* ]]
	[[ "${output}" == *$'demo/dev\tstopped\tmissing\tvalid'* ]]
	[[ "${output}" == *$'demo/prod\tnot-created\tmissing\tvalid'* ]]
	[[ "${output}" != *"vm-vpn-"* ]]

	run "${VM_SCRIPT}" status demo prod
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"config: demo/prod"* ]]
	[[ "${output}" == *"runtime: not-created"* ]]
	[[ "${output}" != *"vm-vpn-"* ]]
}

@test "delete permanently removes the config and hidden clone" {
	"${VM_SCRIPT}" create demo staging
	"${VM_SCRIPT}" start demo staging

	run "${VM_SCRIPT}" delete demo staging
	[ "${status}" -eq 0 ]
	[ ! -e "${VM_VPN_CONFIG_HOME}/demo/staging" ]
	grep -Fxq 'delete vm-vpn-demo-staging' "${TART_LOG}"
}

@test "setup is idempotent and builds only when the base is absent" {
	run "${VM_SCRIPT}" setup
	[ "${status}" -eq 0 ]
	[ ! -e "${TART_LOG}.build" ]

	export TART_BASE_MISSING=1
	printf '%s\n' 'vm-vpn-vault-staging' 'vm-vpn-demo-dev' >"${TART_INSTANCES}"
	mv "${VM_VPN_BASE_MARKER}" "${VM_VPN_BASE_MARKER}.missing"
	run "${VM_SCRIPT}" setup
	[ "${status}" -eq 0 ]
	[ "$(<"${TART_LOG}.build")" = "vm-vpn-base" ]
	[ "$(<"${VM_VPN_BASE_MARKER}")" = "verified:12" ]
	grep -Fxq 'delete vm-vpn-vault-staging' "${TART_LOG}"
	grep -Fxq 'delete vm-vpn-demo-dev' "${TART_LOG}"
	[[ "${output}" == *"removed old runtime for vault/staging; next start will recreate it from the new base image"* ]]
	[[ "${output}" == *"removed old runtime for demo/dev; next start will recreate it from the new base image"* ]]
}

@test "image:build replaces an existing base image without a separate delete" {
	run "${VM_SCRIPT}" image-build
	[ "${status}" -eq 0 ]
	grep -Fxq 'stop vm-vpn-base' "${TART_LOG}"
	grep -Fxq 'delete vm-vpn-base' "${TART_LOG}"
	[ "$(<"${TART_LOG}.build")" = "vm-vpn-base" ]
	[ "$(<"${VM_VPN_BASE_MARKER}")" = "verified:12" ]
}

@test "setup replaces an unverified base while start rejects one" {
	mv "${VM_VPN_BASE_MARKER}" "${VM_VPN_BASE_MARKER}.missing"
	"${VM_SCRIPT}" create demo dev

	run "${VM_SCRIPT}" setup
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"replacing unverified base image"* ]]
	grep -Fxq 'stop vm-vpn-base' "${TART_LOG}"
	grep -Fxq 'delete vm-vpn-base' "${TART_LOG}"
	[ "$(<"${TART_LOG}.build")" = "vm-vpn-base" ]
	[ "$(<"${VM_VPN_BASE_MARKER}")" = "verified:12" ]

	mv "${VM_VPN_BASE_MARKER}" "${VM_VPN_BASE_MARKER}.rebuilt"
	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"base image exists but is not verified"* ]]
}

@test "clean deletes runtime clones whose configs no longer exist" {
	printf '%s\n' 'vm-vpn-demo-dev' 'vm-vpn-demo-prod' >"${TART_INSTANCES}"
	"${VM_SCRIPT}" create demo dev

	run "${VM_SCRIPT}" clean
	[ "${status}" -eq 0 ]
	grep -Fxq 'delete vm-vpn-demo-prod' "${TART_LOG}"
	run grep -Fx 'delete vm-vpn-demo-dev' "${TART_LOG}"
	[ "${status}" -ne 0 ]
}

@test "doctor includes Task in its development-shell checks" {
	grep -Fq 'bats direnv jq nix packer shellcheck shfmt sshpass tart task' "${VM_SCRIPT}"
}

@test "start passes additional --dir mounts declared in mounts.json" {
	"${VM_SCRIPT}" create demo dev
	mkdir -p "${BATS_TEST_TMPDIR}/host/workspace" "${BATS_TEST_TMPDIR}/host/reference"
	cat >"${VM_VPN_CONFIG_HOME}/demo/dev/mounts.json" <<EOF
[
  { "tag": "code", "source": "${BATS_TEST_TMPDIR}/host/workspace" },
  { "tag": "reference", "source": "${BATS_TEST_TMPDIR}/host/reference", "readonly": true }
]
EOF

	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"mounts: valid"* ]]

	grep -Fq -- "--dir code:${BATS_TEST_TMPDIR}/host/workspace" "${TART_LOG}"
	grep -Fq -- "--dir reference:${BATS_TEST_TMPDIR}/host/reference:ro" "${TART_LOG}"
}

@test "start expands ~ in mounts.json source paths" {
	"${VM_SCRIPT}" create demo dev
	export HOME="${BATS_TEST_TMPDIR}/home"
	mkdir -p "${HOME}/workspace"
	cat >"${VM_VPN_CONFIG_HOME}/demo/dev/mounts.json" <<'EOF'
[ { "tag": "code", "source": "~/workspace" } ]
EOF

	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -eq 0 ]
	grep -Fq -- "--dir code:${HOME}/workspace" "${TART_LOG}"
}

@test "start rejects invalid mounts.json" {
	"${VM_SCRIPT}" create demo dev
	printf '{ "not": "an array" }\n' >"${VM_VPN_CONFIG_HOME}/demo/dev/mounts.json"

	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"mounts is invalid"* ]]
}

@test "start rejects mounts.json entries that reuse the workspace tag" {
	"${VM_SCRIPT}" create demo dev
	mkdir -p "${BATS_TEST_TMPDIR}/host/workspace"
	cat >"${VM_VPN_CONFIG_HOME}/demo/dev/mounts.json" <<EOF
[ { "tag": "workspace", "source": "${BATS_TEST_TMPDIR}/host/workspace" } ]
EOF

	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"mounts is invalid"* ]]
}

@test "start fails when a mounts.json source directory does not exist" {
	"${VM_SCRIPT}" create demo dev
	cat >"${VM_VPN_CONFIG_HOME}/demo/dev/mounts.json" <<EOF
[ { "tag": "code", "source": "${BATS_TEST_TMPDIR}/does-not-exist" } ]
EOF

	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"mount source is missing"* ]]
}

@test "validate reports mounts state alongside bookmarks and vpn" {
	"${VM_SCRIPT}" create demo dev

	run "${VM_SCRIPT}" validate demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"mounts: none"* ]]

	mkdir -p "${BATS_TEST_TMPDIR}/host/workspace"
	cat >"${VM_VPN_CONFIG_HOME}/demo/dev/mounts.json" <<EOF
[ { "tag": "code", "source": "${BATS_TEST_TMPDIR}/host/workspace" } ]
EOF
	run "${VM_SCRIPT}" validate demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"mounts: valid"* ]]
}
