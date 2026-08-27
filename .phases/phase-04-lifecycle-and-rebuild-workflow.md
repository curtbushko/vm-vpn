# Phase 4: Lifecycle and Rebuild Workflow

## Objective

Turn the proven `vault/dev` mechanisms into a safe, repo-local lifecycle interface while keeping Tart-specific behavior behind a backend boundary.

## Tasks

- [x] Specify command exit codes, stdout/stderr contracts, non-interactive behavior, and state transitions for `up`, `down`, `restart`, `rebuild`, `status`, and `list`.
- [x] Write failing tests for argument validation, positional-versus-environment behavior, invalid workspaces, and safe error messages.
- [x] Isolate Tart operations behind a backend interface for exists, create, start, stop, status, share, and present.
- [x] Write backend contract tests using a fake Tart executable before connecting commands to real Tart.
- [x] Implement `vm up vault dev` with validation, preflight, deterministic VM lookup/creation, runtime materialization, start, and graphical presentation.
- [x] Implement graceful `vm down vault dev` without deleting VM or browser state.
- [x] Implement `vm restart vault dev` as a graceful stop followed by start.
- [x] Implement `vm rebuild vault dev` so it updates the declarative guest and preserves persistent user/browser state.
- [x] Implement non-sensitive `vm status vault dev` with resolved text/icon identity, VM state, and VPN state.
- [x] Implement `vm list` from the single flake workspace registry with stable machine-readable output and optional interactive styling.
- [x] Add per-workspace state/log paths using `vault/dev`, restrictive modes, and redaction.
- [x] Add explicit recovery behavior for interrupted creation, failed starts, stale runtime material, and unresponsive graceful shutdown.
- [x] Document that destruction is out of scope unless added as a separate, confirmed command; never overload `down` or `rebuild`.
- [x] Run fake-backend tests, Bats, shell lint/format, Nix checks/builds, and the available real Tart restart/rebuild checks.
- [x] Update the Implementation Record with evidence and the next task.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` synchronized.

### 2026-08-27

- All 15 tasks complete. Fake-backend contracts cover creation, start, stop,
  restart, rebuild, status, shares, and the invariant that no command deletes a
  VM. The installed real VM previously passed graceful restart and rebuild
  persistence checks.
- `up` can install an absent VM from an explicit installer ISO, then starts with
  a read-only committed-tree snapshot and materializes local data over stdin.
- Recovery retains disks and restrictive logs. No destroy operation exists.
  Full Bats, ShellCheck, shfmt, Nix formatting, and flake checks pass.
