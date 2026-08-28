#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	VM_COMMAND="${REPO_ROOT}/scripts/vm"
	export VM_VPN_DATA_HOME="${BATS_TEST_TMPDIR}/data"
	export VM_VPN_STATE_HOME="${BATS_TEST_TMPDIR}/state"
	export TART_LOG="${BATS_TEST_TMPDIR}/tart.log"
	export TART_BIN="${BATS_TEST_TMPDIR}/tart"
	cat >"${TART_BIN}" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${TART_LOG}"
case "$1" in
get) [[ "${TART_ABSENT:-0}" != 1 ]] || exit 1; printf 'OS CPU Memory Disk State\nlinux 6 16384 80 running\n' ;;
exec) cat >/dev/null ;;
esac
EOF
	chmod +x "${TART_BIN}"
}

@test "up creates an absent VM through the backend before starting it" {
	printf 'synthetic profile\n' >"${BATS_TEST_TMPDIR}/profile.ovpn"
	printf 'synthetic iso\n' >"${BATS_TEST_TMPDIR}/installer.iso"
	export VM_VPN_INSTALLER_ISO="${BATS_TEST_TMPDIR}/installer.iso"
	export TART_ABSENT=1
	run "${VM_COMMAND}" init vault dev
	run "${VM_COMMAND}" import-vpn vault dev "${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" up vault dev
	[ "${status}" -eq 0 ]
	grep -q '^create --linux vault-dev ' "${TART_LOG}"
	grep -q -- '--display 1440x900' "${TART_LOG}"
	grep -q '^set vault-dev --display-refit$' "${TART_LOG}"
	grep -q '^run vault-dev .*installer.iso' "${TART_LOG}"
}

@test "materialize streams the profile without putting its contents in arguments or logs" {
	canary="secret-${RANDOM}-profile"
	printf '%s\n' "${canary}" >"${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" init vault dev
	run "${VM_COMMAND}" import-vpn vault dev "${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" materialize vault dev
	[ "${status}" -eq 0 ]
	grep -q '^exec -i vault-dev ' "${TART_LOG}"
	grep -q 'start.html' "${TART_LOG}"
	! grep -q "${canary}" "${TART_LOG}"
}

@test "status reports identity and VM state without sensitive data" {
	run "${VM_COMMAND}" status vault dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"vault-dev"* ]]
	[[ "${output}" == *"running"* ]]
}

@test "down and restart use graceful Tart operations without deletion" {
	run "${VM_COMMAND}" down vault dev
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" restart vault dev
	[ "${status}" -eq 0 ]
	grep -q '^stop vault-dev$' "${TART_LOG}"
	for _ in 1 2 3 4 5; do
		grep -q '^run vault-dev' "${TART_LOG}" && break
		sleep 0.05
	done
	grep -q '^run vault-dev' "${TART_LOG}"
	! grep -q 'delete' "${TART_LOG}"
}

@test "rebuild restarts with a read-only source snapshot and switches the guest" {
	run "${VM_COMMAND}" rebuild vault dev
	[ "${status}" -eq 0 ]
	grep -q '^stop vault-dev$' "${TART_LOG}"
	grep -q '^run vault-dev .*:ro' "${TART_LOG}"
	grep -q 'nixos-rebuild switch --flake /mnt/shared/repo#vault-dev' "${TART_LOG}"
	! grep -q 'delete' "${TART_LOG}"
}

@test "help documents the phase one interface" {
	run "${VM_COMMAND}" --help

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"vm identity PRODUCT ENVIRONMENT"* ]]
	[[ "${output}" == *"vm doctor"* ]]
}

@test "init creates restrictive local-only workspace directories idempotently" {
	run "${VM_COMMAND}" init vault dev
	[ "${status}" -eq 0 ]
	[ -d "${VM_VPN_DATA_HOME}/vault/dev/vpn" ]
	[ ! -e "${VM_VPN_DATA_HOME}/vault/dev/vpn/profile.ovpn" ]
	[ "$(stat -c '%a' "${VM_VPN_DATA_HOME}/vault/dev")" = "700" ]
	run "${VM_COMMAND}" init vault dev
	[ "${status}" -eq 0 ]
}

@test "import-vpn copies with mode 0600 and refuses overwrite" {
	printf 'canary profile\n' >"${BATS_TEST_TMPDIR}/source.ovpn"
	run "${VM_COMMAND}" init vault dev
	run "${VM_COMMAND}" import-vpn vault dev "${BATS_TEST_TMPDIR}/source.ovpn"
	[ "${status}" -eq 0 ]
	[ -e "${BATS_TEST_TMPDIR}/source.ovpn" ]
	[ "$(stat -c '%a' "${VM_VPN_DATA_HOME}/vault/dev/vpn/profile.ovpn")" = "600" ]
	run "${VM_COMMAND}" import-vpn vault dev "${BATS_TEST_TMPDIR}/source.ovpn"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"already exists"* ]]
}

@test "bookmark and certificate imports preserve sources and reject collisions" {
	printf '[{"title":"Synthetic","url":"https://synthetic.invalid"}]\n' >"${BATS_TEST_TMPDIR}/bookmarks.json"
	printf 'synthetic certificate fixture\n' >"${BATS_TEST_TMPDIR}/test-ca.crt"
	run "${VM_COMMAND}" init vault dev
	run "${VM_COMMAND}" import-bookmarks vault dev "${BATS_TEST_TMPDIR}/bookmarks.json"
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" import-cert vault dev "${BATS_TEST_TMPDIR}/test-ca.crt"
	[ "${status}" -eq 0 ]
	[ -f "${BATS_TEST_TMPDIR}/bookmarks.json" ]
	[ -f "${BATS_TEST_TMPDIR}/test-ca.crt" ]
	[ "$(stat -c '%a' "${VM_VPN_DATA_HOME}/vault/dev/bookmarks/bookmarks.json")" = "600" ]
	[ "$(stat -c '%a' "${VM_VPN_DATA_HOME}/vault/dev/certs/test-ca.crt")" = "600" ]
	run "${VM_COMMAND}" import-cert vault dev "${BATS_TEST_TMPDIR}/test-ca.crt"
	[ "${status}" -ne 0 ]
}

@test "preflight rejects absent profile without exposing a path body" {
	run "${VM_COMMAND}" init vault dev
	run "${VM_COMMAND}" preflight vault dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"VPN profile is missing"* ]]
}

@test "list emits the flake registry workspace" {
	run "${VM_COMMAND}" list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'"vmName":"vault-dev"'* ]]
}

@test "identity derives vault dev names in canonical order" {
	run "${VM_COMMAND}" identity vault dev

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"PRODUCT=vault"* ]]
	[[ "${output}" == *"ENVIRONMENT=dev"* ]]
	[[ "${output}" == *"VM_NAME=vault-dev"* ]]
	[[ "${output}" == *"VM_PATH=vault/dev"* ]]
}

@test "identity rejects unsafe names" {
	run "${VM_COMMAND}" identity Vault dev

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"lowercase hostname-safe"* ]]
}

@test "identity rejects unknown phase one workspace" {
	run "${VM_COMMAND}" identity vault prod

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"workspace is not configured"* ]]
}

@test "second workspace resolves independently" {
	run "${VM_COMMAND}" identity consul lab
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"VM_NAME=consul-lab"* ]]
	[[ "${output}" == *"VM_PATH=consul/lab"* ]]
}

@test "two workspaces keep local data state and Tart names isolated" {
	printf 'vault fixture\n' >"${BATS_TEST_TMPDIR}/vault.ovpn"
	printf 'consul fixture\n' >"${BATS_TEST_TMPDIR}/consul.ovpn"
	run "${VM_COMMAND}" init vault dev
	run "${VM_COMMAND}" init consul lab
	run "${VM_COMMAND}" import-vpn vault dev "${BATS_TEST_TMPDIR}/vault.ovpn"
	run "${VM_COMMAND}" import-vpn consul lab "${BATS_TEST_TMPDIR}/consul.ovpn"
	run "${VM_COMMAND}" up vault dev
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" up consul lab
	[ "${status}" -eq 0 ]
	[ -f "${VM_VPN_DATA_HOME}/vault/dev/vpn/profile.ovpn" ]
	[ -f "${VM_VPN_DATA_HOME}/consul/lab/vpn/profile.ovpn" ]
	grep -q '^run vault-dev ' "${TART_LOG}"
	grep -q '^run consul-lab ' "${TART_LOG}"
}

@test "diagnose reports presence and modes without reading sensitive contents" {
	canary="diagnostic-${RANDOM}-secret"
	printf '%s\n' "${canary}" >"${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" init vault dev
	run "${VM_COMMAND}" import-vpn vault dev "${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" diagnose vault dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"PROFILE_PRESENT=yes"* ]]
	[[ "${output}" == *"PROFILE_MODE=600"* ]]
	[[ "${output}" != *"${canary}"* ]]
}

@test "cleanup moves recoverable operational state to trash without touching data or VM" {
	mkdir -p "${VM_VPN_STATE_HOME}/vault/dev/sources/example"
	printf 'log\n' >"${VM_VPN_STATE_HOME}/vault/dev/tart.log"
	run "${VM_COMMAND}" cleanup vault dev
	[ "${status}" -eq 0 ]
	[ -d "${VM_VPN_STATE_HOME}/vault/dev/.trash" ]
	[ ! -e "${VM_VPN_STATE_HOME}/vault/dev/sources" ]
	! grep -q 'delete' "${TART_LOG}"
}

@test "diagnose degrades safely when Tart is unavailable" {
	export TART_BIN="${BATS_TEST_TMPDIR}/missing-tart"
	run "${VM_COMMAND}" diagnose vault dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"TART_VERSION=unavailable"* ]]
	[[ "${output}" == *"GUEST_REACHABLE=no"* ]]
}
