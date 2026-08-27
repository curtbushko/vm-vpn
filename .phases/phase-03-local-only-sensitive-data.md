# Phase 3: Local-Only Sensitive Data

## Objective

Establish the complete local-data and Nix-store boundary for `vault/dev`, including safe imports and ephemeral guest materialization.

## Tasks

- [ ] Threat-model host storage, Tart shares/copies, guest runtime paths, logs, process arguments, Nix derivations, and persistent browser state.
- [ ] Choose and document the simplest proven runtime transport to `/run/vpn-workspace` that does not copy plaintext through the Nix store.
- [ ] Write failing Bats tests for canonical XDG path derivation and validation of `vault/dev` against the flake workspace registry.
- [ ] Implement one central path resolver for `${XDG_DATA_HOME:-$HOME/.local/share}/vm-vpn/vault/dev`.
- [ ] Write failing tests for `vm init vault dev`, including idempotency, `0700` directories, no fabricated VPN profile, and no overwrite.
- [ ] Implement `vm init` with clear canonical paths and restrictive permissions.
- [ ] Write failing tests for `vm import-vpn`, `vm import-bookmarks`, and `vm import-cert`, including missing sources, collision safety, preserved sources, filenames, and `0600` destination modes.
- [ ] Implement the three import commands without overwrite by default.
- [ ] Write failing checks for preflight behavior when required local files are absent or permissions are unsafe.
- [ ] Implement runtime materialization of the VPN profile, bookmarks, and certificates into tmpfs-backed guest paths with cleanup on shutdown.
- [ ] Configure the proven SAML VPN mechanism to read only runtime material.
- [ ] Implement runtime Firefox bookmark/start-page integration without embedding internal URLs in Nix-generated store paths.
- [ ] Implement runtime certificate trust/client-certificate handling with explicit ownership and permissions.
- [ ] Add redaction rules so routine status and logs never print endpoints, internal URLs, profile bodies, credentials, or private key data.
- [ ] Scan Git objects, the source tree, evaluated derivations, build closures, and relevant store references for seeded canary secrets; prove the canaries remain absent.
- [ ] Re-run real `vault/dev` SAML, DNS, routing, browser, bookmark, and certificate tests using local-only data.
- [ ] Run all checks and update the Implementation Record with evidence and the next task.

## Implementation Constraints

- Shell code follows the Bash skill: `set -euo pipefail`, quoted variables, no `eval`, Bats-first tests, and clean `shellcheck`/`shfmt`.
- Sensitive workspace data is never committed, including encrypted variants, and must never be created beneath the repository.
- Do not use `.gitignore` as the sensitive-data boundary.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` synchronized.
