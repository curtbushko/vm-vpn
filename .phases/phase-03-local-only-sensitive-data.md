# Phase 3: Local-Only Sensitive Data

## Objective

Establish the complete local-data and Nix-store boundary for `demo/dev`, including safe imports and ephemeral guest materialization.

## Tasks

- [x] Threat-model host storage, Tart shares/copies, guest runtime paths, logs, process arguments, Nix derivations, and persistent browser state.
- [x] Choose and document the simplest proven runtime transport to `/run/vpn-workspace` that does not copy plaintext through the Nix store.
- [x] Write failing Bats tests for canonical XDG path derivation and validation of `demo/dev` against the flake workspace registry.
- [x] Implement one central path resolver for `${XDG_DATA_HOME:-$HOME/.local/share}/vm-vpn/demo/dev`.
- [x] Write failing tests for `vm init demo dev`, including idempotency, `0700` directories, no fabricated VPN profile, and no overwrite.
- [x] Implement `vm init` with clear canonical paths and restrictive permissions.
- [x] Write failing tests for `vm import-vpn`, `vm import-bookmarks`, and `vm import-cert`, including missing sources, collision safety, preserved sources, filenames, and `0600` destination modes.
- [x] Implement the three import commands without overwrite by default.
- [x] Write failing checks for preflight behavior when required local files are absent or permissions are unsafe.
- [x] Implement runtime materialization of the VPN profile, bookmarks, and certificates into tmpfs-backed guest paths with cleanup on shutdown.
- [x] Configure the proven SAML VPN mechanism to read only runtime material.
- [x] Implement runtime Firefox bookmark/start-page integration without embedding internal URLs in Nix-generated store paths.
- [x] Implement runtime certificate trust/client-certificate handling with explicit ownership and permissions.
- [x] Add redaction rules so routine status and logs never print endpoints, internal URLs, profile bodies, credentials, or private key data.
- [x] Scan Git objects, the source tree, evaluated derivations, build closures, and relevant store references for seeded canary secrets; prove the canaries remain absent.
- [x] Run synthetic `demo/dev` materialization, browser-link, certificate, and redaction tests; defer real SAML/network acceptance to Phase 6.
- [x] Run all checks and update the Implementation Record with evidence and the next task.

## Implementation Constraints

- Shell code follows the Bash skill: `set -euo pipefail`, quoted variables, no `eval`, Bats-first tests, and clean `shellcheck`/`shfmt`.
- Sensitive workspace data is never committed, including encrypted variants, and must never be created beneath the repository.
- Do not use `.gitignore` as the sensitive-data boundary.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` synchronized.

### 2026-08-27

- All 17 tasks complete with synthetic sensitive fixtures. Host paths use XDG
  conventions and strict modes; imports preserve sources and reject overwrite.
- Runtime data is streamed over guest-agent stdin to tmpfs. The SAML client,
  generated start page, CA trust, and password-file-backed PKCS#12 imports use
  runtime paths only. Endpoint and profile contents are absent from logs.
- The full automated suite and key-pattern scans pass. Real AWS authentication
  and connected network behavior remain explicitly deferred to Phase 6.
