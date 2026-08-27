# Phase 6: Hardening and Operations

## Objective

Complete operational safeguards and refinements after the core multi-workspace design is proven.

## Tasks

- [x] Add VPN runtime-material state to Quickshell using resolved icons/colors without leaking endpoints or private network details.
- [x] Finalize controlled host-share configuration with explicit allowlisted host and guest paths and least-privilege defaults.
- [x] Define and enforce clipboard, drag/drop, notification, download, and guest-to-host transfer policies.
- [x] Add safe diagnostics that report versions, VM state, guest reachability, runtime-file presence, and permission problems without reading sensitive contents.
- [x] Define VM disk protection, backup, restore, retention, and secret-rotation procedures while treating browser/session state as sensitive.
- [x] Add explicit, conservative cleanup workflows that move recoverable local artifacts to `.trash/`; persistent VM destruction remains separately confirmed.
- [x] Add regression tests for interrupted operations, permission repair, stale mounts, partial imports, missing browsers/profiles, and unavailable Tart.
- [x] Add CI-safe checks that never require or discover local sensitive workspace data and never attempt live SAML.
- [x] Write root-level usage and troubleshooting documentation limited to repo-root commands inside the development shell.
- [x] Run the complete automated suite and synthetic acceptance pass; explicitly record the five real-network criteria as deferred rather than passed.
- [x] Record final evidence, accepted limitations, deferred ideas, and ongoing maintenance commands in the Implementation Record.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` synchronized.

### 2026-08-27

- All implementation and synthetic acceptance tasks are complete. Quickshell
  shows only safe VPN readiness, lifecycle disables clipboard/audio, shares are
  committed-tree/read-only, and diagnostics disclose no sensitive contents.
- Recoverable cleanup moves operational artifacts beneath `.trash`; no command
  destroys a VM. Backup/restore/rotation and interaction policies are recorded
  in `docs/operations.md`.
- `vm check` runs the complete CI-safe suite. Five external acceptance facts
  remain deferred: real SAML, real client connection, guest VPN DNS/routes,
  approved internal reachability, and unchanged host networking during one or
  two live VPN sessions. Synthetic results must not be cited as those facts.
