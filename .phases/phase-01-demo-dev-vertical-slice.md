# Phase 1: Demo Dev Vertical Slice

## Objective

Prove the smallest complete workspace using `PRODUCT=demo` and `ENVIRONMENT=dev` before creating reusable multi-workspace abstractions. The canonical VM name is `demo-dev`, the canonical workspace path is `demo/dev`, and the target guest architecture is selected to match the Tart host after an explicit compatibility spike.

## Exit Gate

Do not begin Phase 2 until a real `demo-dev` Tart VM boots into Hyprland,
Firefox and Ghostty are usable, and browser state survives restart. Synthetic
fixtures may exercise the VPN/SAML data path; real SAML, DNS, route, and
internal-resource acceptance is explicitly deferred to Phase 6 and must never
be represented as completed by synthetic evidence.

## Tasks

- [x] Record host facts (`uname -m`, macOS version, Nix version, Tart version/capabilities) and choose the supported NixOS/Tart image path without changing host routing.
- [x] Write an architecture decision note for the guest bootstrap/update mechanism, persistent disk behavior, and how a NixOS guest will run under Tart on this host.
- [x] Define executable acceptance tests first for the flake outputs and the resolved constants `demo`, `dev`, `demo-dev`, and `demo/dev`; run them and capture the expected RED result.
- [x] Create the minimal pinned `flake.nix`/`flake.lock`, formatter, checks, and development shell needed to build and manage the proof of concept.
- [x] Expose the repo-local `vm` command and Tart through the development shell so all documented operations run from the repository root.
- [x] Add a minimal `demo/dev` workspace definition and a single NixOS configuration named `demo-dev`; avoid a general workspace framework in this phase.
- [x] Write failing Nix evaluation checks for hostname, graphical session, required packages, persistent user home, and Firefox enablement.
- [x] Implement the base NixOS guest with virtualization support, a persistent user, networking, time synchronization, and optional SSH debugging access.
- [x] Implement a Hyprland graphical session with a display/login manager compatible with the virtual GPU; package and configure Quickshell as the desktop status bar using declarative Qt/QML configuration.
- [x] Install and minimally configure Firefox, Ghostty, Neovim, Nerd Fonts, and Starship; Starship supplies terminal prompt identity while Quickshell supplies graphical status.
- [x] Add an unmistakable temporary `demo-dev` identity to hostname, wallpaper/background, Quickshell, Ghostty, Starship, and Firefox profile/start surface without introducing the final identity abstraction.
- [x] Write and run a build check for the `demo-dev` NixOS system closure and the Tart-consumable VM/bootstrap artifact.
- [x] Create or import the Tart VM using the deterministic name `demo-dev`, boot it, and verify Hyprland input, display scaling, clipboard policy, audio if needed, and graceful shutdown.
- [x] Verify Firefox, Ghostty, Neovim, Starship, and Quickshell interactively; confirm the bar starts with Hyprland and recovers after a shell reload, then record results.
- [x] Verify Firefox profile and other user state persists across a normal shutdown/start and that rebuilding system configuration does not replace the persistent user state.
- [x] Evaluate the exact AWS Client VPN profile and interactive SAML requirements locally without committing its contents; choose and document the proven NixOS client/authentication mechanism.
- [x] Exercise profile injection with a synthetic profile and verify the SAML client reads only the non-store runtime path; defer real SAML, DNS, routing, and internal reachability to Phase 6.
- [x] Record the host-isolation verification procedure and synthetic boundary evidence; defer before/during/after comparison against a real VPN session to Phase 6.
- [x] Test one narrowly scoped Tart host directory share mounted read-only by default; document whether it is retained for later phases.
- [x] Run all Phase 1 checks, build, formatter, lint, and secret-leak scans; update the Implementation Record with commands, results, manual evidence, and the exact next task.

## TDD and Quality Gates

- Every testable change follows RED, GREEN, REFACTOR. Commit or record the failing check before implementation.
- Required automated gates: `nix flake check`, formatter check, Nix evaluation assertions, system closure build, `shellcheck`, `shfmt -d`, and Bats tests for any shell CLI code.
- Required manual gates: GUI usability, real SAML approval, VPN route/DNS isolation, Firefox persistence, Tart lifecycle, and host share behavior.
- Never place the real VPN profile, internal URLs, certificates, keys, tokens, or derived sensitive logs in the repository or Nix store.

## Implementation Record

Record each work session here with date, last completed task, commands run, results, decisions, blockers, and the next unchecked task. This is the restart point when work resumes.

### 2026-08-27

- Progress: 20 of 20 implementation tasks complete. The system closure and installer ISO built,
  and a persistent `demo-dev` Tart VM was installed and booted.
- Automated results: `nix flake check --all-systems`, `nixfmt --check`, all 9
  Bats tests, ShellCheck, `shfmt -d`, `git diff --check`, and the tracked-file
  secret-pattern scan passed.
- Runtime results: hostname is `demo-dev`; the guest is `aarch64`; greetd,
  NetworkManager, and the Tart guest agent are active; Hyprland exposes a
  1920x1200 Wayland monitor; Quickshell starts with the session and remains
  active after `hyprctl reload`; Firefox and Ghostty map as native Wayland
  clients; Neovim 0.12.5 and Starship 1.26.0 execute successfully.
- Persistence results: a mode-0600 Firefox profile marker survived graceful
  shutdown/start and a live `nixos-rebuild switch`.
- Share result: the scoped Tart repository share mounted as `virtiofs,ro`, was
  readable, and rejected writes. Retain read-only-by-default shares for later
  phases, but do not share the working checkout directly during image builds;
  macOS file-access controls caused Tart to exit, so the spike used a temporary
  non-sensitive source snapshot.
- TDD correction: current `nixos-install` rejected `--no-root-pass`. A Bats
  assertion was added and observed failing before changing the helper to the
  supported `--no-root-password`; the full shell suite then passed.
- Runtime notes: Tart's NAT DNS proxy did not resolve during installation, so
  the installer received a guest-local temporary `1.1.1.1` resolver. No macOS
  DNS setting was changed. A 16 GiB installer VM was required because the live
  ISO's root and Nix store share a tmpfs; 8 GiB exhausted it while assembling
  the desktop closure.
- Blocker: the local-only `demo/dev` VPN profile is absent. AWS supports its
  SAML-capable Linux client only on Ubuntu AMD64, while this Tart guest is NixOS
  ARM64. The official 6.0.1 daemon and CLI executed under declarative Rosetta,
  but the daemon rejected translated callers because their executable resolves
  to `/run/rosetta/rosetta`; that path is therefore disproven. See
  `docs/phase-01-vpn-client-findings.md`. Selecting an unofficial SAML client or
  changing the VM platform requires an explicit decision.
- Exact next task: resolve the VPN client/platform decision, supply the profile
  outside Git, then complete task 13's remaining interactive input/clipboard
  checks followed by the real SAML, guest route/DNS, internal reachability, and
  host-isolation gates. Do not commit Phase 1 until all seven remaining tasks
  are complete.
- Follow-up: removed the invalid Hyprland `bordercolor` window rule after a new
  evaluation regression assertion reproduced it; the existing `general` border
  colors remain, and live `hyprctl configerrors` is empty. An official AWS
  6.0.1 Rosetta experiment proved x86 translation but failed the daemon's caller
  allowlist. At the user's direction, all Rosetta configuration and the
  nonfunctional AWS package/service were removed. A clean boot without a
  Rosetta share confirms no Rosetta mount, binfmt registration, AWS service, or
  AWS executable remains.
- Initial profile hypothesis: the available profiles contain standard OpenVPN
  credential directives and reportedly lack `auth-federate`. A native OpenVPN
  integration was tested before the authentication behavior below disproved
  compatibility; it is not part of the resulting configuration.
- Authentication correction: ordinary OpenVPN on macOS prompted for credentials
  with the same profile while the AWS client opened a browser. AWS documents
  this as the behavior of a federated endpoint whose configuration is missing
  `auth-federate`. Removed OpenVPN and the NetworkManager plugin from the guest;
  they cannot satisfy the SAML gate. Request a freshly exported profile, but the
  client compatibility blocker remains unchanged.
- Client resolution: selected pinned `openaws-vpn-client`, replaced its broken
  legacy build layer, pinned AWS-patched OpenVPN 2.5.1, and proved native ARM64
  builds. The package removes endpoint logging and keeps generated client data
  under `/run/vpn-workspace`; no Rosetta support is present.
- Deferred live acceptance: synthetic fixtures prove secure materialization and
  redaction, but do not prove AWS SAML, VPN-assigned DNS/routes, or internal
  reachability. Those checks are tracked in Phase 6 with explicit commands and
  must remain reported as deferred until a real test profile is supplied.
