# ADR 0001: Bootstrap NixOS on Tart

## Status

Accepted for the Phase 1 proof of concept.

## Context

The host is Apple Silicon and Tart supports ARM64 Linux guests created from an
attached installer ISO. The host Nix installation cannot execute
`aarch64-linux` derivations and its configured `linux-builder` is not currently
resolvable. A NixOS installer image therefore needs a Linux execution
environment before the final workspace VM can be created.

The workspace must retain browser and user state across configuration rebuilds.
Tart owns the VM disk, while NixOS owns the installed system configuration.

## Decision

1. Pin the official Tart release archive as a Nix package for
   `aarch64-darwin`. Expose Tart and every other host-side management tool from
   the repository development shell.
2. Bootstrap an ARM64 Linux Tart VM from an official Linux base image and
   install Nix in that guest.
3. Give the builder a read-only VirtioFS view of the repository and a separate,
   narrow writable artifact share. Invoke builds with Tart's guest-exec channel
   rather than configuring a host-global remote builder.
4. Build an `aarch64-linux` NixOS installer ISO inside the builder and copy only
   the resulting ISO into the artifact share.
5. Create the workspace as a persistent Tart Linux VM named `vault-dev`, boot
   the installer ISO, and install NixOS onto the Tart-owned disk.
6. Apply later NixOS configurations through Tart guest exec or SSH and
   `nixos-rebuild`, preserving the installed disk and `/home/vpn`.
7. Keep Tart lifecycle details behind the repo-local `vm` command. Routine
   commands run only from the repository root inside `nix develop`.
8. Use Tart's default shared NAT networking for the proof of concept. The VPN
   runs only in the guest; no customer route or DNS setting is applied to
   macOS.
9. Use an explicitly named, read-only VirtioFS share for the Phase 1 host-share
   test. Linux mounts the tag manually at a narrow guest path.

## Persistence Boundary

- NixOS system configuration is declarative and replaceable.
- Tart's primary disk persists across `down`, `up`, and `rebuild`.
- `/home/vpn`, including Firefox's profile, remains on that disk.
- Runtime VPN material is injected outside the Nix store and is not part of
  the installer or system closure.
- Destroying the Tart VM is not part of `down` or `rebuild`.

## Consequences

- The first build has a Linux-builder bootstrap step.
- A real graphical boot, SAML approval, route/DNS isolation, and persistence
  test remain manual Phase 1 gates.
- The Phase 1 VM is intentionally a vertical slice. Reusable workspace and
  identity abstractions wait until Phase 2.

## Sources

- Tart quick start and Linux VM creation:
  <https://github.com/openai/tart/blob/main/docs/quick-start.md>
- Tart Linux clipboard and VirtioFS behavior:
  <https://github.com/openai/tart/blob/main/Sources/tart/Commands/Run.swift>
