#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	CONNECT_COMMAND="${REPO_ROOT}/scripts/aws-vpn-connect"
	export XDG_RUNTIME_DIR="${BATS_TEST_TMPDIR}/runtime"
	export AWS_VPN_PROFILE="${BATS_TEST_TMPDIR}/profile.ovpn"
	export AWS_VPN_CLIENT_BIN="${BATS_TEST_TMPDIR}/aws-vpn-client"
	export AWS_VPN_OPENVPN_BIN="${BATS_TEST_TMPDIR}/openvpn"
	export AWS_VPN_SUDO_BIN="${BATS_TEST_TMPDIR}/sudo"
	export AWS_VPN_DNS_SCRIPT="${BATS_TEST_TMPDIR}/update-systemd-resolved"
	export AWS_VPN_TEST_LOG="${BATS_TEST_TMPDIR}/calls.log"
	mkdir -p "${XDG_RUNTIME_DIR}"
	cat >"${AWS_VPN_PROFILE}" <<'EOF'
client
remote cvpn-endpoint-123.prod.clientvpn.us-east-1.amazonaws.com 443
auth-user-pass
auth-retry interact
auth-nocache
EOF
	cat >"${AWS_VPN_CLIENT_BIN}" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${AWS_VPN_TEST_LOG}"
printf '%s\n' '2026/01/01 Remote IP: 192.0.2.10' >&2
printf '%s\n' 'N/A' 'CRV1::fixture::response'
EOF
	cat >"${AWS_VPN_OPENVPN_BIN}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	cat >"${AWS_VPN_SUDO_BIN}" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${AWS_VPN_TEST_LOG}"
profile=''
while (($#)); do
	if [[ "$1" == '--config' ]]; then profile="$2"; break; fi
	shift
done
grep -q '^auth-nocache$' "${profile}"
! grep -q '^auth-user-pass' "${profile}"
! grep -q '^auth-retry[[:space:]]\+interact' "${profile}"
EOF
	cat >"${AWS_VPN_DNS_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	chmod +x "${AWS_VPN_CLIENT_BIN}" "${AWS_VPN_OPENVPN_BIN}" "${AWS_VPN_SUDO_BIN}" "${AWS_VPN_DNS_SCRIPT}"
}

@test "authenticates in the browser and passes SAML credentials to patched OpenVPN" {
	run "${CONNECT_COMMAND}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"Opening AWS sign-in in Firefox"* ]]
	grep -q -- "-ovpn ${AWS_VPN_OPENVPN_BIN}" "${AWS_VPN_TEST_LOG}"
	grep -q -- '--remote 192.0.2.10 443' "${AWS_VPN_TEST_LOG}"
	grep -q -- "--up ${AWS_VPN_DNS_SCRIPT}" "${AWS_VPN_TEST_LOG}"
	grep -q -- "--down ${AWS_VPN_DNS_SCRIPT}" "${AWS_VPN_TEST_LOG}"
	[ -n "$(find "${XDG_RUNTIME_DIR}/.trash" -type f -name credentials -size 0 -print -quit)" ]
	[ -z "$(find "${XDG_RUNTIME_DIR}" -maxdepth 1 -type d -name 'aws-vpn-client.*' -print -quit)" ]
}

@test "fails before authentication when the VPN profile is missing" {
	export AWS_VPN_PROFILE="${BATS_TEST_TMPDIR}/missing.ovpn"
	run "${CONNECT_COMMAND}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"VPN profile not found"* ]]
}
