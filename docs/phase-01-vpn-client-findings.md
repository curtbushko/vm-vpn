# Phase 1 AWS Client VPN Findings

## Result

The selected mechanism is the unofficial, open-source
`ethan605/aws-vpn-client`, pinned at revision
`fc27bc5de33c4ebbb2d5f7c4a6f220d734cb9666`. This repository builds the pinned
Go source with current pinned Nixpkgs and its AWS patch for OpenVPN 2.6.3. Both build natively for
`aarch64-linux`; Rosetta is not configured or used.

The host CLI streams local-only files over Tart guest-agent stdin into the
tmpfs-backed `/run/vpn-workspace` directory. A floating terminal runs a wrapper
which sanitizes conflicting password directives, invokes the client to open the
AWS SAML URL in Firefox, and passes the returned credentials to patched
OpenVPN. Profile contents and SAML credentials are not placed in command
arguments. Real-profile SAML, DNS, routing, and internal reachability remain
interactive acceptance checks.

Testing the
same profile with ordinary OpenVPN on macOS produced a username/password prompt,
while the AWS provided client opened the browser. That browser behavior confirms
the endpoint uses AWS's federated authentication flow even though the available
profile does not contain `auth-federate`.

AWS documents this exact missing-flag behavior and recommends exporting the
latest endpoint configuration. AWS also explicitly states that OpenVPN-based
clients cannot connect to SAML-federated Client VPN endpoints. The temporary
native OpenVPN and NetworkManager plugin integration was therefore removed from
the VM so the configuration does not imply compatibility.

## Rejected SAML paths

The installed guest is NixOS on `aarch64-linux`, matching the Apple Silicon
host and Tart virtual CPU. AWS documents its provided Linux client as supported
only on Ubuntu 22.04, 24.04, or 26.04 on AMD64. The published package repository
and standalone package are also explicitly AMD64. AWS requires its provided
client for SAML-federated Client VPN endpoints.

Consequently, the official AWS client cannot currently be called a supported or
proven mechanism for this NixOS ARM64 guest. An unofficial patched OpenVPN/SAML
client changes the trust and support model; the user explicitly selected that
tradeoff for this workspace.

### Rosetta experiment

The official 6.0.1 AMD64 package was downloaded from AWS and verified against
AWS's published SHA-256 digest. NixOS's `virtualisation.rosetta` module was then
enabled with Tart's `--rosetta rosetta` share. The binfmt registration became
active and an x86_64 GNU Hello binary ran successfully, proving translation.

The AWS daemon and CLI were packaged with their x86_64 runtime dependencies and
both executed. The daemon nevertheless rejected CLI requests with:

```text
Binary path of caller PID is /run/rosetta/rosetta, not allowed
```

Rosetta necessarily appears as the executable in the translated process. That
conflicts with the closed-source daemon's caller-binary allowlist, so the
official client is not functional through Rosetta without bypassing an upstream
security control. The package and service experiment was therefore removed.
Rosetta support was removed from the VM at the user's direction. The notes above
remain only to prevent the rejected path from being repeated.

## Inputs still required

- A real profile at the local-only path
  `~/.local/share/vm-vpn/demo/dev/vpn/profile.ovpn` (or an explicitly supplied
  equivalent path).
- An approved internal resource used only for a reachability assertion. Its URL
  or address must remain outside Git and the Nix store.
- A newly exported endpoint profile should be checked for `auth-federate`, but
  the profile must remain outside Git and the Nix store.
- Acceptance of the explicitly selected unofficial reverse-engineered SAML
  client for this workspace.

## Official references

- AWS Linux client requirements:
  <https://docs.aws.amazon.com/vpn/latest/clientvpn-user/client-vpn-connect-linux.html>
- AWS Linux installation packages:
  <https://docs.aws.amazon.com/vpn/latest/clientvpn-user/client-vpn-connect-linux-install.html>
- AWS SAML requirements:
  <https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/federated-authentication.html>

## Restart procedure

1. Enter `nix develop` and run `vm doctor`.
2. Confirm the profile exists and inspect only its permissions and directive
   names; never print its certificates, keys, endpoint, or SAML data into logs.
3. Record host route and DNS hashes while `demo-dev` is running but before the
   VPN connection.
4. Implement the approved client mechanism test-first, inject the profile only
   into a non-store guest runtime path, and complete SAML interactively.
5. Verify guest routes, guest DNS, the approved internal resource, and unchanged
   host route/DNS hashes during and after disconnect.
