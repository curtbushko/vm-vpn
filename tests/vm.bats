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
	if [[ "${2:-}" != "vm-vpn-base" ]] && ! grep -Fxq "${2:-}" "${TART_INSTANCES}"; then
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

@test "build creates only the reusable base image" {
	run "${VM_SCRIPT}" build
	[ "${status}" -eq 0 ]
	[ "$(<"${TART_LOG}.build")" = "vm-vpn-base" ]
}

@test "Task routes create arguments to the internal VM implementation" {
	run task --taskfile "${REPO_ROOT}/Taskfile.yml" create -- demo dev
	[ "${status}" -eq 0 ]
	grep -Fxq 'clone vm-vpn-base vm-vpn-demo-dev' "${TART_LOG}"
}

@test "create makes protected host configuration and a persistent clone" {
	run "${VM_SCRIPT}" create demo dev
	[ "${status}" -eq 0 ]
	[ -d "${VM_VPN_CONFIG_HOME}/demo/dev/vpn" ]
	[ -d "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks" ]
	[ -d "${VM_VPN_CONFIG_HOME}/demo/dev/shared" ]
	if [[ "$(uname -s)" == "Darwin" ]]; then
		mode="$(/usr/bin/stat -f '%Lp' "${VM_VPN_CONFIG_HOME}/demo/dev")"
	else
		mode="$(stat -c '%a' "${VM_VPN_CONFIG_HOME}/demo/dev")"
	fi
	[ "${mode}" = "700" ]
	[ "$(jq -c . "${VM_VPN_CONFIG_HOME}/demo/dev/bookmarks/bookmarks.json")" = "[]" ]
	grep -Fxq 'clone vm-vpn-base vm-vpn-demo-dev' "${TART_LOG}"

	run "${VM_SCRIPT}" create demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"already exists"* ]]
}

@test "three clones start concurrently with independent dynamic configuration" {
	for environment in dev staging prod; do
		"${VM_SCRIPT}" create demo "${environment}"
		run "${VM_SCRIPT}" start demo "${environment}"
		[ "${status}" -eq 0 ]
	done

	grep -Fq "run vm-vpn-demo-dev --dir ${VM_VPN_CONFIG_HOME}/demo/dev:ro,tag=workspace" "${TART_LOG}"
	grep -Fq "run vm-vpn-demo-staging --dir ${VM_VPN_CONFIG_HOME}/demo/staging:ro,tag=workspace" "${TART_LOG}"
	grep -Fq "run vm-vpn-demo-prod --dir ${VM_VPN_CONFIG_HOME}/demo/prod:ro,tag=workspace" "${TART_LOG}"
}

@test "start rejects a missing or unsafe instance" {
	run "${VM_SCRIPT}" start demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"task create -- demo dev"* ]]

	run "${VM_SCRIPT}" create '../demo' dev
	[ "${status}" -ne 0 ]
}

@test "stop status and delete target one derived instance" {
	"${VM_SCRIPT}" create demo staging

	run "${VM_SCRIPT}" stop demo staging
	[ "${status}" -eq 0 ]
	run "${VM_SCRIPT}" status demo staging
	[ "${status}" -eq 0 ]
	run "${VM_SCRIPT}" delete demo staging
	[ "${status}" -eq 0 ]

	grep -Fxq 'stop vm-vpn-demo-staging' "${TART_LOG}"
	grep -Fxq 'get vm-vpn-demo-staging' "${TART_LOG}"
	grep -Fxq 'delete vm-vpn-demo-staging' "${TART_LOG}"
	[ -d "${VM_VPN_CONFIG_HOME}/demo/staging" ]
}

@test "list and stop-all operate only on managed instances" {
	"${VM_SCRIPT}" create demo dev
	"${VM_SCRIPT}" create demo prod

	run "${VM_SCRIPT}" list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"vm-vpn-demo-dev"* ]]
	[[ "${output}" == *"vm-vpn-demo-prod"* ]]
	run "${VM_SCRIPT}" stop-all
	[ "${status}" -eq 0 ]
	grep -Fxq 'stop vm-vpn-demo-dev' "${TART_LOG}"
	grep -Fxq 'stop vm-vpn-demo-prod' "${TART_LOG}"
}

@test "doctor includes Task in its development-shell checks" {
	grep -Fq 'bats direnv jq nix packer shellcheck shfmt sshpass tart task' "${VM_SCRIPT}"
}
