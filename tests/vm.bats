#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	VM_SCRIPT="${REPO_ROOT}/scripts/vm"
	export VM_VPN_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
	export VM_VPN_REPO_ROOT="${REPO_ROOT}"
	export VM_VPN_BUILD_SCRIPT="${BATS_TEST_TMPDIR}/build-image"
	export TART_LOG="${BATS_TEST_TMPDIR}/tart.log"
	export TART_INSTANCES="${BATS_TEST_TMPDIR}/instances"
	export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
	mkdir -p "${BATS_TEST_TMPDIR}/bin"
	: >"${TART_INSTANCES}"

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
	[ "$(jq -c . "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks/bookmarks.json")" = "[]" ]
	[ ! -s "${TART_LOG}" ]

	run "${VM_SCRIPT}" create demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"configuration already exists"* ]]
}

@test "start lazily creates and then reuses the hidden runtime clone" {
	"${VM_SCRIPT}" create demo dev

	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -eq 0 ]
	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -eq 0 ]

	[ "$(grep -Fc 'clone vm-vpn-base vm-vpn-demo--dev' "${TART_LOG}")" -eq 1 ]
	[ "$(grep -Fc "run vm-vpn-demo--dev --dir ${VM_VPN_CONFIG_HOME}/demo/dev:ro,tag=workspace" "${TART_LOG}")" -eq 2 ]
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

@test "multiple configs start independent hidden VMs concurrently" {
	for environment in dev staging prod; do
		"${VM_SCRIPT}" create demo "${environment}"
		run "${VM_SCRIPT}" start demo "${environment}"
		[ "${status}" -eq 0 ]
	done

	grep -Fq 'clone vm-vpn-base vm-vpn-demo--dev' "${TART_LOG}"
	grep -Fq 'clone vm-vpn-base vm-vpn-demo--staging' "${TART_LOG}"
	grep -Fq 'clone vm-vpn-base vm-vpn-demo--prod' "${TART_LOG}"
}

@test "validate reports bookmark and VPN readiness" {
	"${VM_SCRIPT}" create demo dev

	run "${VM_SCRIPT}" validate demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"bookmarks: valid"* ]]
	[[ "${output}" == *"vpn: missing"* ]]

	printf 'client\nremote vpn.example.com 443\n' >"${VM_VPN_CONFIG_HOME}/demo/dev/vpn/profile.ovpn"
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
	grep -Fxq 'delete vm-vpn-demo--staging' "${TART_LOG}"
}

@test "setup is idempotent and builds only when the base is absent" {
	run "${VM_SCRIPT}" setup
	[ "${status}" -eq 0 ]
	[ ! -e "${TART_LOG}.build" ]

	export TART_BASE_MISSING=1
	run "${VM_SCRIPT}" setup
	[ "${status}" -eq 0 ]
	[ "$(<"${TART_LOG}.build")" = "vm-vpn-base" ]
}

@test "clean deletes runtime clones whose configs no longer exist" {
	printf '%s\n' 'vm-vpn-demo--dev' 'vm-vpn-demo--prod' >"${TART_INSTANCES}"
	"${VM_SCRIPT}" create demo dev

	run "${VM_SCRIPT}" clean
	[ "${status}" -eq 0 ]
	grep -Fxq 'delete vm-vpn-demo--prod' "${TART_LOG}"
	run grep -Fx 'delete vm-vpn-demo--dev' "${TART_LOG}"
	[ "${status}" -ne 0 ]
}

@test "doctor includes Task in its development-shell checks" {
	grep -Fq 'bats direnv jq nix packer shellcheck shfmt sshpass tart task' "${VM_SCRIPT}"
}
