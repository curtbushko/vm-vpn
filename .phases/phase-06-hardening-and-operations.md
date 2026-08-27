# Phase 6: Hardening and Operations

## Objective

Complete operational safeguards and refinements after the core multi-workspace design is proven.

## Tasks

- [ ] Add VPN connection state to Quickshell using resolved icons/colors without leaking endpoints or private network details.
- [ ] Finalize controlled host-share configuration with explicit allowlisted host and guest paths and least-privilege defaults.
- [ ] Define and enforce clipboard, drag/drop, notification, download, and guest-to-host transfer policies.
- [ ] Add safe diagnostics that report versions, VM state, guest reachability, runtime-file presence, and permission problems without reading sensitive contents.
- [ ] Define VM disk protection, backup, restore, retention, and secret-rotation procedures while treating browser/session state as sensitive.
- [ ] Add explicit, conservative cleanup workflows that move recoverable local artifacts to `.trash/`; persistent VM destruction remains separately confirmed.
- [ ] Add regression tests for interrupted operations, permission repair, stale mounts, partial imports, missing browsers/profiles, and unavailable Tart.
- [ ] Add CI-safe checks that never require or discover local sensitive workspace data and never attempt live SAML.
- [ ] Write root-level usage and troubleshooting documentation limited to repo-root commands inside the development shell.
- [ ] Run the complete automated suite and a final manual acceptance pass against all 23 design acceptance criteria.
- [ ] Record final evidence, accepted limitations, deferred ideas, and ongoing maintenance commands in the Implementation Record.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` synchronized.
