# Lifecycle Commands

Run every command from the repository root inside `nix develop`.

- `vm init PRODUCT ENVIRONMENT` creates local-only host directories.
- `vm up PRODUCT ENVIRONMENT` validates local data, creates a missing Tart VM
  from `VM_VPN_INSTALLER_ISO`, starts it with a read-only committed-source
  snapshot, and streams runtime material.
- `vm down PRODUCT ENVIRONMENT` requests a graceful stop. It never deletes the
  VM or browser state.
- `vm restart PRODUCT ENVIRONMENT` stops and starts the same disk.
- `vm rebuild PRODUCT ENVIRONMENT` restarts with an immutable source snapshot
  and runs `nixos-rebuild switch` in the guest.
- `vm status PRODUCT ENVIRONMENT` reports only canonical identity, Tart state,
  and whether runtime VPN material is ready.
- `vm list` emits one compact JSON object per workspace from the flake registry.

Exit status zero means the requested transition completed. Validation and
preflight failures use stderr and nonzero status without printing sensitive
paths or contents. Creation failures retain the VM and installer log beneath
the restrictive per-workspace state directory for recovery. Re-running `up`
continues with an existing VM; installation itself supports `--resume`.

Source snapshots contain only the committed Git tree. This prevents local-only
data and unrelated uncommitted files from becoming VM shares. Snapshots and
logs use `${XDG_STATE_HOME:-$HOME/.local/state}/vm-vpn/PRODUCT/ENVIRONMENT`.

There is intentionally no destroy command. Removing a persistent VM is a
separate destructive operation outside this interface.
