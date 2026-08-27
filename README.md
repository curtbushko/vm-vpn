# VPN Workspace VMs

Declarative graphical NixOS VPN workspaces running under Tart on Apple Silicon.
The first workspace is `vault/dev`; `consul/lab` is a synthetic second identity
used to prove isolation and scaling.

Run all commands from this repository root:

```console
nix develop
vm doctor
vm init vault dev
vm import-vpn vault dev /path/to/profile.ovpn
vm up vault dev
vm status vault dev
vm down vault dev
```

`vm up` needs `VM_VPN_INSTALLER_ISO` only when `vault-dev` does not already
exist. Build/export `.#vault-dev-installer` on an ARM64 Linux builder and point
the variable at that ISO. Existing VMs do not need it.

The VM provides Hyprland, Quickshell, Firefox, Ghostty, Neovim, Starship, and
native ARM64 `openaws-vpn-client`. Press Super+B for Firefox, Super+Return for
Ghostty, and Super+L to lock.

Sensitive files live outside Git under `~/.local/share/vm-vpn`. See
`docs/local-data-security.md`, `docs/lifecycle.md`, and `docs/operations.md`.
Run `vm check` before commits. If startup fails, use
`vm diagnose PRODUCT ENVIRONMENT`; it reports presence and modes without
reading sensitive contents.
