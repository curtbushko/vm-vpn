# VPN Workspace VMs

Declarative graphical NixOS VPN workspaces running under Tart on Apple Silicon.
Each workspace is identified by a lowercase `<product>` and `<environment>`;
the initial workspace is `demo/dev`. The VM name is
`<product>-<environment>`.

The guest provides Hyprland, Quickshell, Firefox, Ghostty, Neovim, Starship,
and the native ARM64 `openaws-vpn-client`. It does not use Rosetta. Press
Super+B for Firefox, Super+Return for Ghostty, and Super+L to lock. Click
**Applications** in the top menu bar or press Super+Space to search installed
graphical applications. The bottom dock directly launches Firefox, Ghostty,
and the VPN client. Neovim remains available from Ghostty and the command line
rather than the graphical menus. The Mac Command key is Hyprland's main
modifier, so Command+Space, Command+Return, Command+B, and Command+L invoke the
same shortcuts shown as `Super` inside Linux. Clipboard sharing is enabled for
copy and paste between macOS and every VM.

## Setup

Run commands from the repository root. Nix bootstraps the development shell,
which provides every other required host tool. The shell deliberately keeps
the host's Nix executable so it remains compatible with the host Nix
configuration. With direnv's shell hook enabled, approve this repository once
and future visits will load the flake development shell automatically:

```console
direnv allow
```

Without direnv integration, enter the same environment manually:

```console
nix develop
vm doctor
vm list
vm seed demo dev
vm up demo dev
```

`vm seed demo dev` creates a complete synthetic workspace using the tracked
fixtures under `examples/demo/dev`. It installs a non-working example OpenVPN
profile, a valid example CA certificate, and bookmarks for the
[Vault documentation](https://developer.hashicorp.com/vault/docs),
[AWS Client VPN guide](https://docs.aws.amazon.com/vpn/latest/clientvpn-user/what-is.html),
[NixOS options](https://search.nixos.org/options), and
[Hyprland documentation](https://wiki.hypr.land/). It also configures the
tracked `examples` directory as read-only and creates a writable `output`
directory. No real VPN credentials or private keys are included.

`vm up` requires `VM_VPN_INSTALLER_ISO` only when the corresponding Tart VM
does not exist. Build or export `.#demo-dev-installer` on an ARM64 Linux
builder, then set the variable to the resulting ISO path. Existing VMs do not
need the ISO.

## Commands

### Information and validation

```console
vm identity <product> <environment>
vm list
vm preflight <product> <environment>
vm status <product> <environment>
vm diagnose <product> <environment>
vm doctor
vm check
vm --help
```

- `identity` prints the canonical workspace and VM names.
- `list` prints every workspace registered by the flake.
- `preflight` validates required local data and permissions.
- `status` reports the Tart and runtime-material states.
- `diagnose` reports versions, presence, modes, and reachability without
  printing sensitive contents.
- `doctor` checks that the development-shell tools are available.
- `check` runs tests, linting, formatting checks, and flake evaluation.

### Local workspace data

```console
vm init <product> <environment>
vm seed <product> <environment>
vm import-vpn <product> <environment> /absolute/path/to/profile.ovpn
vm import-bookmarks <product> <environment> /absolute/path/to/bookmarks.json
vm import-cert <product> <environment> /absolute/path/to/certificate
vm materialize <product> <environment>
vm cleanup <product> <environment>
```

- `init` creates the protected host data directories.
- `seed` installs a workspace's tracked demonstration fixtures and settings;
  fixtures currently exist for `demo/dev`.
- Import commands copy their source, set mode `0600`, and refuse to overwrite
  an existing destination.
- `materialize` streams the local data into guest tmpfs at
  `/run/vpn-workspace`; it does not persistently share the sensitive host data.
- `cleanup` moves source snapshots and logs into the state directory's
  `.trash/` subtree. It does not remove imported data or the Tart VM.

### VM lifecycle

```console
vm up <product> <environment>
vm down <product> <environment>
vm restart <product> <environment>
vm rebuild <product> <environment>
```

- `up` validates data, creates a missing VM, starts it, mounts configured host
  directories, and materializes runtime data.
- `down` gracefully stops the VM without deleting its disk.
- `restart` stops and starts the same VM disk.
- `rebuild` restarts the VM and applies the committed NixOS configuration.

There is intentionally no VM deletion command.

### Host directories

```console
vm share-add <product> <environment> <name> /absolute/host/path
vm share-add <product> <environment> <name> /absolute/host/path --read-write
vm share-list <product> <environment>
vm share-remove <product> <environment> <name>
```

Share names must contain lowercase letters, numbers, and single hyphens. The
name `repo` is reserved. Paths must be absolute existing directories and may
not contain colons, tabs, or newlines.

Shares default to read-only. `--read-write` is an explicit opt-in to host write
access. A configured share appears inside the guest at
`/mnt/shared/<name>`. Removing a setting never removes or changes the host
directory.

## Host settings and storage

The defaults below follow the XDG base-directory convention. Paths are scoped
independently by `<product>/<environment>`.

| Purpose | Default host path | Override |
| --- | --- | --- |
| User-facing settings | `~/.config/vm-vpn/<product>/<environment>/` | `VM_VPN_CONFIG_HOME`, then `XDG_CONFIG_HOME` |
| Sensitive imported data | `~/.local/share/vm-vpn/<product>/<environment>/` | `VM_VPN_DATA_HOME`, then `XDG_DATA_HOME` |
| Snapshots and logs | `~/.local/state/vm-vpn/<product>/<environment>/` | `VM_VPN_STATE_HOME`, then `XDG_STATE_HOME` |

### `~/.config/vm-vpn/*` settings

Host-directory settings are stored in:

```text
~/.config/vm-vpn/<product>/<environment>/shares.json
```

The directory has mode `0700` and `shares.json` has mode `0600`. The file is a
JSON array managed by `vm share-add`, `vm share-list`, and `vm share-remove`:

```json
[
  {
    "name": "source",
    "path": "/absolute/path/to/source",
    "mode": "ro"
  },
  {
    "name": "output",
    "path": "/absolute/path/to/output",
    "mode": "rw"
  }
]
```

| Field | Meaning |
| --- | --- |
| `name` | Guest directory name beneath `/mnt/shared`; `repo` is reserved. |
| `path` | Canonical absolute host directory path. |
| `mode` | `ro` for the default read-only mount or `rw` for explicit read-write access. |

Use the `vm share-*` commands instead of editing this file directly so names,
paths, collisions, permissions, and modes are validated.

### Sensitive data layout

```text
~/.local/share/vm-vpn/<product>/<environment>/
├── vpn/
│   └── profile.ovpn
├── bookmarks/
│   └── bookmarks.json
└── certs/
    └── <imported-certificate>
```

Directories use mode `0700`; imported files use mode `0600`. This tree is not
mounted into the VM. `materialize` streams it to the guest's temporary
`/run/vpn-workspace` directory.

### Operational state layout

```text
~/.local/state/vm-vpn/<product>/<environment>/
├── sources/
│   └── <git-revision>/
├── tart.log
├── installer.log
└── .trash/
```

Source snapshots contain only the committed Git revision. The committed source
is available read-only in the guest at `/mnt/shared/repo`. Logs and snapshots
may be moved beneath `.trash/` by `vm cleanup`.

## Environment variables

| Variable | Purpose |
| --- | --- |
| `VM_VPN_CONFIG_HOME` | Replaces the entire default `~/.config/vm-vpn` root. |
| `VM_VPN_DATA_HOME` | Replaces the entire default `~/.local/share/vm-vpn` root. |
| `VM_VPN_STATE_HOME` | Replaces the entire default `~/.local/state/vm-vpn` root. |
| `VM_VPN_INSTALLER_ISO` | Absolute installer ISO path used only to create a missing VM. |
| `VM_VPN_REPO_ROOT` | Repository used for flake evaluation and committed source snapshots; set automatically by `nix develop`. |
| `XDG_CONFIG_HOME` | Changes the config base when `VM_VPN_CONFIG_HOME` is unset. |
| `XDG_DATA_HOME` | Changes the data base when `VM_VPN_DATA_HOME` is unset. |
| `XDG_STATE_HOME` | Changes the state base when `VM_VPN_STATE_HOME` is unset. |

See [local data security](docs/local-data-security.md),
[lifecycle behavior](docs/lifecycle.md), and
[operations and deferred live acceptance](docs/operations.md) for the security
boundary and current testing limitations.
