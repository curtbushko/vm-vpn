# Phase 2: Resolved Workspace Identity

## Objective

Replace Phase 1 constants with one validated, declarative identity model while preserving the working `vault/dev` VM.

## Entry Gate

Phase 1's Tart, Hyprland, persistence, and real SAML proof must be complete. Reuse the proven mechanisms; do not redesign them without a recorded failure.

## Tasks

- [ ] Write failing evaluation tests for allowed product/environment syntax, canonical name/path derivation, missing definitions, and duplicate VM names.
- [ ] Add `products/vault.nix` with the Vault Nerd Font icon and product color-family defaults.
- [ ] Add `environments/dev.nix` with the development icon and accent/background/foreground palette.
- [ ] Refactor `workspaces/vault/dev.nix` to contain only workspace-specific, non-sensitive settings and `displayName`.
- [ ] Implement `lib/identity.nix` to resolve common defaults, product defaults, environment defaults, and workspace overrides.
- [ ] Implement `lib/mkWorkspace.nix` so `PRODUCT`, `ENVIRONMENT`, `VM_NAME`, and `PRODUCT/ENVIRONMENT` are derived once and shared by flake outputs and guest modules.
- [ ] Add evaluation tests proving `vault-dev` is the hostname, Tart name, NixOS configuration name, and status identity while `vault/dev` is the filesystem identity.
- [ ] Generate a non-sensitive wallpaper from the resolved identity and assert that no local runtime data is an input.
- [ ] Refactor Hyprland/Quickshell, Ghostty, Starship, Firefox visual identity, hostname, and lock screen to consume the resolved identity through generated, non-sensitive Qt/QML properties where appropriate.
- [ ] Ensure identity uses redundant text/icons and does not rely on color alone.
- [ ] Expose a machine-readable workspace registry from the flake and ensure lifecycle tooling consumes it rather than maintaining a second list.
- [ ] Run automated checks and rebuild `vault-dev`, verifying its persistent Firefox/user state remains intact.
- [ ] Update the Implementation Record with evidence, decisions, and the next task.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` progress and status synchronized with completed checkboxes.
