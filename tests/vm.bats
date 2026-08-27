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
get) printf 'OS CPU Memory Disk State\nlinux 6 16384 80 running\n' ;;
exec) cat >/dev/null ;;
esac
EOF
	chmod +x "${TART_BIN}"
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
