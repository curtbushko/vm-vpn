#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	VM_COMMAND="${REPO_ROOT}/scripts/vm"
	export VM_VPN_DATA_HOME="${BATS_TEST_TMPDIR}/data"
	export VM_VPN_STATE_HOME="${BATS_TEST_TMPDIR}/state"
	export VM_VPN_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
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

@test "seed populates demo data and user-facing share settings" {
	run "${VM_COMMAND}" seed demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" != *"warning: unknown setting 'eval-cores'"* ]]
	[[ "${output}" != *"warning: unknown setting 'lazy-trees'"* ]]
	root="${VM_VPN_DATA_HOME}/demo/dev"
	[ "$(stat -c '%a' "${root}/vpn/profile.ovpn")" = "600" ]
	[ "$(stat -c '%a' "${root}/bookmarks/bookmarks.json")" = "600" ]
	[ "$(stat -c '%a' "${root}/certs/demo-ca.crt")" = "600" ]
	grep -q '^auth-user-pass$' "${root}/vpn/profile.ovpn"
	jq -e 'length >= 3 and all(.[]; .url | startswith("https://"))' "${root}/bookmarks/bookmarks.json"
	jq -e 'any(.[]; .url == "https://developer.hashicorp.com/vault/docs")' "${root}/bookmarks/bookmarks.json"
	jq -e 'any(.[]; .url == "https://docs.aws.amazon.com/vpn/latest/clientvpn-user/what-is.html")' "${root}/bookmarks/bookmarks.json"
	openssl x509 -in "${root}/certs/demo-ca.crt" -noout -subject >/dev/null
	run "${VM_COMMAND}" share-list demo dev
	[ "${status}" -eq 0 ]
	printf '%s\n' "${output}" | tail -n 1 | jq -e 'any(.[]; .name == "examples" and .mode == "ro")'
	printf '%s\n' "${output}" | tail -n 1 | jq -e 'any(.[]; .name == "output" and .mode == "rw")'
}

@test "share-add records a validated read-only setting by default" {
	mkdir -p "${BATS_TEST_TMPDIR}/host source"
	run "${VM_COMMAND}" share-add demo dev source "${BATS_TEST_TMPDIR}/host source"
	[ "${status}" -eq 0 ]
	[ "$(stat -c '%a' "${VM_VPN_CONFIG_HOME}/demo/dev/shares.json")" = "600" ]
	run "${VM_COMMAND}" share-list demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'"name":"source"'* ]]
	[[ "${output}" == *'"mode":"ro"'* ]]
}

@test "share-add requires explicit opt-in for read-write and rejects collisions" {
	mkdir -p "${BATS_TEST_TMPDIR}/output"
	run "${VM_COMMAND}" share-add demo dev output "${BATS_TEST_TMPDIR}/output" --read-write
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" share-add demo dev output "${BATS_TEST_TMPDIR}/output"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"already configured"* ]]
	run "${VM_COMMAND}" share-list demo dev
	[[ "${output}" == *'"mode":"rw"'* ]]
}

@test "share-remove removes only the named setting" {
	mkdir -p "${BATS_TEST_TMPDIR}/one" "${BATS_TEST_TMPDIR}/two"
	run "${VM_COMMAND}" share-add demo dev one "${BATS_TEST_TMPDIR}/one"
	run "${VM_COMMAND}" share-add demo dev two "${BATS_TEST_TMPDIR}/two"
	run "${VM_COMMAND}" share-remove demo dev one
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" share-list demo dev
	[[ "${output}" != *'"name":"one"'* ]]
	[[ "${output}" == *'"name":"two"'* ]]
	[ -d "${BATS_TEST_TMPDIR}/one" ]
}

@test "configured host shares are passed to Tart with the committed snapshot" {
	printf 'fixture\n' >"${BATS_TEST_TMPDIR}/profile.ovpn"
	mkdir -p "${BATS_TEST_TMPDIR}/source"
	run "${VM_COMMAND}" init demo dev
	run "${VM_COMMAND}" import-vpn demo dev "${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" share-add demo dev source "${BATS_TEST_TMPDIR}/source"
	run "${VM_COMMAND}" up demo dev
	[ "${status}" -eq 0 ]
	expected_path="$(realpath "${BATS_TEST_TMPDIR}/source")"
	grep -q -- "--dir source:${expected_path}" "${TART_LOG}"
	run grep -q -- '--no-clipboard' "${TART_LOG}"
	[ "${status}" -ne 0 ]
	grep -q 'bash -lc' "${TART_LOG}"
	grep -q 'mount -t virtiofs com.apple.virtio-fs.automount /run/vm-vpn-host' "${TART_LOG}"
	grep -q 'mount -o remount,bind,ro.*source' "${TART_LOG}"
}

@test "up creates an absent VM through the backend before starting it" {
	printf 'synthetic profile\n' >"${BATS_TEST_TMPDIR}/profile.ovpn"
	printf 'synthetic iso\n' >"${BATS_TEST_TMPDIR}/installer.iso"
	export VM_VPN_INSTALLER_ISO="${BATS_TEST_TMPDIR}/installer.iso"
	export TART_ABSENT=1
	run "${VM_COMMAND}" init demo dev
	run "${VM_COMMAND}" import-vpn demo dev "${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" up demo dev
	[ "${status}" -eq 0 ]
	grep -q '^create --linux demo-dev --disk-size 80$' "${TART_LOG}"
	grep -q '^set demo-dev --cpu 6 --memory 16384 --display 1440x900 --display-refit$' "${TART_LOG}"
	grep -q '^run demo-dev .*installer.iso.*--dir .*:ro,tag=repo' "${TART_LOG}"
	grep -q 'mount -t virtiofs repo /mnt/shared/repo' "${TART_LOG}"
	grep -q -- '--resume' "${TART_LOG}"
}

@test "materialize streams the profile without putting its contents in arguments or logs" {
	canary="secret-${RANDOM}-profile"
	printf '%s\n' "${canary}" >"${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" init demo dev
	run "${VM_COMMAND}" import-vpn demo dev "${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" materialize demo dev
	[ "${status}" -eq 0 ]
	grep -q '^exec -i demo-dev ' "${TART_LOG}"
	grep -q 'start.html' "${TART_LOG}"
	! grep -q "${canary}" "${TART_LOG}"
}

@test "status reports identity and VM state without sensitive data" {
	run "${VM_COMMAND}" status demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"demo-dev"* ]]
	[[ "${output}" == *"running"* ]]
}

@test "down and restart use graceful Tart operations without deletion" {
	run "${VM_COMMAND}" down demo dev
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" restart demo dev
	[ "${status}" -eq 0 ]
	grep -q '^stop demo-dev$' "${TART_LOG}"
	for _ in 1 2 3 4 5; do
		grep -q '^run demo-dev' "${TART_LOG}" && break
		sleep 0.05
	done
	grep -q '^run demo-dev' "${TART_LOG}"
	run grep -q -- '--no-clipboard' "${TART_LOG}"
	[ "${status}" -ne 0 ]
	! grep -q 'delete' "${TART_LOG}"
}

@test "graphical VM launch is detached from the development shell" {
	grep -Eq 'nohup .*tart_bin.* run ' "${VM_COMMAND}"
}

@test "rebuild restarts with a read-only source snapshot and switches the guest" {
	mkdir -p "${BATS_TEST_TMPDIR}/rebuild-source"
	run "${VM_COMMAND}" share-add demo dev rebuild-source "${BATS_TEST_TMPDIR}/rebuild-source"
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" rebuild demo dev
	[ "${status}" -eq 0 ]
	grep -q '^stop demo-dev$' "${TART_LOG}"
	grep -q '^run demo-dev .*--dir repo:' "${TART_LOG}"
	grep -q 'mount -o remount,bind,ro.*rebuild-source' "${TART_LOG}"
	grep -q 'nixos-rebuild switch --flake /mnt/shared/repo#demo-dev' "${TART_LOG}"
	! grep -q 'delete' "${TART_LOG}"
}

@test "help documents the phase one interface" {
	run "${VM_COMMAND}" --help

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"vm identity PRODUCT ENVIRONMENT"* ]]
	[[ "${output}" == *"vm doctor"* ]]
}

@test "init creates restrictive local-only workspace directories idempotently" {
	run "${VM_COMMAND}" init demo dev
	[ "${status}" -eq 0 ]
	[ -d "${VM_VPN_DATA_HOME}/demo/dev/vpn" ]
	[ ! -e "${VM_VPN_DATA_HOME}/demo/dev/vpn/profile.ovpn" ]
	[ "$(stat -c '%a' "${VM_VPN_DATA_HOME}/demo/dev")" = "700" ]
	run "${VM_COMMAND}" init demo dev
	[ "${status}" -eq 0 ]
}

@test "import-vpn copies with mode 0600 and refuses overwrite" {
	printf 'canary profile\n' >"${BATS_TEST_TMPDIR}/source.ovpn"
	run "${VM_COMMAND}" init demo dev
	run "${VM_COMMAND}" import-vpn demo dev "${BATS_TEST_TMPDIR}/source.ovpn"
	[ "${status}" -eq 0 ]
	[ -e "${BATS_TEST_TMPDIR}/source.ovpn" ]
	[ "$(stat -c '%a' "${VM_VPN_DATA_HOME}/demo/dev/vpn/profile.ovpn")" = "600" ]
	run "${VM_COMMAND}" import-vpn demo dev "${BATS_TEST_TMPDIR}/source.ovpn"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"already exists"* ]]
}

@test "bookmark and certificate imports preserve sources and reject collisions" {
	printf '[{"title":"Synthetic","url":"https://synthetic.invalid"}]\n' >"${BATS_TEST_TMPDIR}/bookmarks.json"
	printf 'synthetic certificate fixture\n' >"${BATS_TEST_TMPDIR}/test-ca.crt"
	run "${VM_COMMAND}" init demo dev
	run "${VM_COMMAND}" import-bookmarks demo dev "${BATS_TEST_TMPDIR}/bookmarks.json"
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" import-cert demo dev "${BATS_TEST_TMPDIR}/test-ca.crt"
	[ "${status}" -eq 0 ]
	[ -f "${BATS_TEST_TMPDIR}/bookmarks.json" ]
	[ -f "${BATS_TEST_TMPDIR}/test-ca.crt" ]
	[ "$(stat -c '%a' "${VM_VPN_DATA_HOME}/demo/dev/bookmarks/bookmarks.json")" = "600" ]
	[ "$(stat -c '%a' "${VM_VPN_DATA_HOME}/demo/dev/certs/test-ca.crt")" = "600" ]
	run "${VM_COMMAND}" import-cert demo dev "${BATS_TEST_TMPDIR}/test-ca.crt"
	[ "${status}" -ne 0 ]
}

@test "preflight rejects absent profile without exposing a path body" {
	run "${VM_COMMAND}" init demo dev
	run "${VM_COMMAND}" preflight demo dev
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"VPN profile is missing"* ]]
}

@test "list emits the flake registry workspace" {
	run "${VM_COMMAND}" list
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'"vmName":"demo-dev"'* ]]
}

@test "identity derives demo dev names in canonical order" {
	run "${VM_COMMAND}" identity demo dev

	[ "${status}" -eq 0 ]
	[[ "${output}" == *"PRODUCT=demo"* ]]
	[[ "${output}" == *"ENVIRONMENT=dev"* ]]
	[[ "${output}" == *"VM_NAME=demo-dev"* ]]
	[[ "${output}" == *"VM_PATH=demo/dev"* ]]
}

@test "identity rejects unsafe names" {
	run "${VM_COMMAND}" identity Demo dev

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"lowercase hostname-safe"* ]]
}

@test "identity rejects unknown phase one workspace" {
	run "${VM_COMMAND}" identity other prod

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
	printf 'demo fixture\n' >"${BATS_TEST_TMPDIR}/demo.ovpn"
	printf 'consul fixture\n' >"${BATS_TEST_TMPDIR}/consul.ovpn"
	run "${VM_COMMAND}" init demo dev
	run "${VM_COMMAND}" init consul lab
	run "${VM_COMMAND}" import-vpn demo dev "${BATS_TEST_TMPDIR}/demo.ovpn"
	run "${VM_COMMAND}" import-vpn consul lab "${BATS_TEST_TMPDIR}/consul.ovpn"
	run "${VM_COMMAND}" up demo dev
	[ "${status}" -eq 0 ]
	run "${VM_COMMAND}" up consul lab
	[ "${status}" -eq 0 ]
	[ -f "${VM_VPN_DATA_HOME}/demo/dev/vpn/profile.ovpn" ]
	[ -f "${VM_VPN_DATA_HOME}/consul/lab/vpn/profile.ovpn" ]
	grep -q '^run demo-dev ' "${TART_LOG}"
	grep -q '^run consul-lab ' "${TART_LOG}"
}

@test "diagnose reports presence and modes without reading sensitive contents" {
	canary="diagnostic-${RANDOM}-secret"
	printf '%s\n' "${canary}" >"${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" init demo dev
	run "${VM_COMMAND}" import-vpn demo dev "${BATS_TEST_TMPDIR}/profile.ovpn"
	run "${VM_COMMAND}" diagnose demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"PROFILE_PRESENT=yes"* ]]
	[[ "${output}" == *"PROFILE_MODE=600"* ]]
	[[ "${output}" != *"${canary}"* ]]
}

@test "cleanup moves recoverable operational state to trash without touching data or VM" {
	mkdir -p "${VM_VPN_STATE_HOME}/demo/dev/sources/example"
	printf 'log\n' >"${VM_VPN_STATE_HOME}/demo/dev/tart.log"
	run "${VM_COMMAND}" cleanup demo dev
	[ "${status}" -eq 0 ]
	[ -d "${VM_VPN_STATE_HOME}/demo/dev/.trash" ]
	[ ! -e "${VM_VPN_STATE_HOME}/demo/dev/sources" ]
	! grep -q 'delete' "${TART_LOG}"
}

@test "diagnose degrades safely when Tart is unavailable" {
	export TART_BIN="${BATS_TEST_TMPDIR}/missing-tart"
	run "${VM_COMMAND}" diagnose demo dev
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"TART_VERSION=unavailable"* ]]
	[[ "${output}" == *"GUEST_REACHABLE=no"* ]]
}
