# Phase 4: Lifecycle and Rebuild Workflow

## Objective

Turn the proven `vault/dev` mechanisms into a safe, repo-local lifecycle interface while keeping Tart-specific behavior behind a backend boundary.

## Tasks

- [ ] Specify command exit codes, stdout/stderr contracts, non-interactive behavior, and state transitions for `up`, `down`, `restart`, `rebuild`, `status`, and `list`.
- [ ] Write failing tests for argument validation, positional-versus-environment behavior, invalid workspaces, and safe error messages.
- [ ] Isolate Tart operations behind a backend interface for exists, create, start, stop, status, share, and present.
- [ ] Write backend contract tests using a fake Tart executable before connecting commands to real Tart.
- [ ] Implement `vm up vault dev` with validation, preflight, deterministic VM lookup/creation, runtime materialization, start, and graphical presentation.
- [ ] Implement graceful `vm down vault dev` without deleting VM or browser state.
- [ ] Implement `vm restart vault dev` as a graceful stop followed by start.
- [ ] Implement `vm rebuild vault dev` so it updates the declarative guest and preserves persistent user/browser state.
- [ ] Implement non-sensitive `vm status vault dev` with resolved text/icon identity, VM state, and VPN state.
- [ ] Implement `vm list` from the single flake workspace registry with stable machine-readable output and optional interactive styling.
- [ ] Add per-workspace state/log paths using `vault/dev`, restrictive modes, and redaction.
- [ ] Add explicit recovery behavior for interrupted creation, failed starts, stale runtime material, and unresponsive graceful shutdown.
- [ ] Document that destruction is out of scope unless added as a separate, confirmed command; never overload `down` or `rebuild`.
- [ ] Run fake-backend tests, Bats, shell lint/format, Nix checks/builds, and real Tart lifecycle tests.
- [ ] Update the Implementation Record with evidence and the next task.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` synchronized.
