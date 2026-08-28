# Phase 2: Resolved Workspace Identity

## Objective

Replace Phase 1 constants with one validated, declarative identity model while preserving the working `demo/dev` VM.

## Entry Gate

Phase 1's Tart, Hyprland, persistence, and real SAML proof must be complete. Reuse the proven mechanisms; do not redesign them without a recorded failure.

## Tasks

- [x] Write failing evaluation tests for allowed product/environment syntax, canonical name/path derivation, missing definitions, and duplicate VM names.
- [x] Add `products/demo.nix` with the Demo Nerd Font icon and product color-family defaults.
- [x] Add `environments/dev.nix` with the development icon and accent/background/foreground palette.
- [x] Refactor `workspaces/demo/dev.nix` to contain only workspace-specific, non-sensitive settings and `displayName`.
- [x] Implement `lib/identity.nix` to resolve common defaults, product defaults, environment defaults, and workspace overrides.
- [x] Implement `lib/mkWorkspace.nix` so `PRODUCT`, `ENVIRONMENT`, `VM_NAME`, and `PRODUCT/ENVIRONMENT` are derived once and shared by flake outputs and guest modules.
- [x] Add evaluation tests proving `demo-dev` is the hostname, Tart name, NixOS configuration name, and status identity while `demo/dev` is the filesystem identity.
- [x] Generate a non-sensitive wallpaper from the resolved identity and assert that no local runtime data is an input.
- [x] Refactor Hyprland/Quickshell, Ghostty, Starship, Firefox visual identity, hostname, and lock screen to consume the resolved identity through generated, non-sensitive Qt/QML properties where appropriate.
- [x] Ensure identity uses redundant text/icons and does not rely on color alone.
- [x] Expose a machine-readable workspace registry from the flake and ensure lifecycle tooling consumes it rather than maintaining a second list.
- [x] Run automated checks and rebuild `demo-dev`, verifying its persistent Firefox/user state remains intact.
- [x] Update the Implementation Record with evidence, decisions, and the next task.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` progress and status synchronized with completed checkboxes.

### 2026-08-27

- All 13 tasks complete. Evaluation tests cover invalid and missing identities,
  duplicate registry entries, canonical names, and guest hostname propagation.
- Product, environment, and workspace declarations resolve through one identity
  model consumed by the flake registry and every visual surface.
- A live `nixos-rebuild switch` preserved the existing Firefox profile marker.
  Full Bats, shell lint/format, Nix formatting, and flake checks passed.
