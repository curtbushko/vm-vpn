# macOS VPN Workspace VM

This project builds a small, reusable macOS Sequoia appliance for Tart. The
guest contains Firefox, Ghostty, and AWS VPN Client. Nix remains the host-side
development environment and supplies Packer, Tart, shell tooling, and tests.

The appliance uses two virtual CPUs, 6 GB of memory, and the Cirrus Labs
`macos-sequoia-vanilla` image. The inherited 50 GB raw disk remains sparse on
the host. Packer removes its trailing recovery partition, while SIP and
authenticated-root protection remain enabled.

## Development shell

Run all build and test commands from the repository root. Direnv can load the
development shell automatically:

```console
direnv allow
```

Or enter it explicitly:

```console
nix develop
```

## Build the golden image

```console
nix develop -c packer init macos/packer
nix develop -c macos/scripts/build-image vm-vpn-macos-compact
```

The build clones
`ghcr.io/cirruslabs/macos-sequoia-vanilla:latest`, installs Tart's guest
agent, Firefox, Ghostty, and AWS VPN Client, applies application defaults, and
stops the completed image. The Dock contains only those three applications.

Provisioning fixes the guest and Firefox language to US English, enables the
Firefox bookmarks toolbar, installs Bitwarden and 1Password extensions, uses a
dark browser theme, and removes first-launch quarantine attributes. It also
disables unneeded synchronization, indexing, update, notification, location,
AI, analytics, backup, sleep, and visual-effect services.

## Create and run a workspace

Clone the golden image once for each `<product>/<environment>`:

```console
nix develop -c tart clone vm-vpn-macos-compact <product>-<environment>
nix develop -c tart run <product>-<environment> \
  --dir="$HOME/.config/vm-vpn/<product>/<environment>:ro,tag=workspace"
```

The host directory is read-only by default. Use `:rw,tag=workspace` only when
the guest must write to it. Tart exposes the directory inside macOS as:

```text
/Volumes/My Shared Files/workspace
```

Stop a workspace without deleting it:

```console
nix develop -c tart stop <product>-<environment>
```

## `~/.config/vm-vpn/*` settings

Each workspace reads its user-facing files from:

```text
~/.config/vm-vpn/<product>/<environment>/
├── vpn/
│   └── profile.ovpn
├── bookmarks/
│   └── bookmarks.json
└── shared/
```

- `vpn/*.ovpn` files are copied inside the guest to the AWS-required
  `~/.config/AWSVPNClient/OpenVpnConfigs` directory with mode `0600`.
- `bookmarks/bookmarks.json` is imported into Firefox when its checksum
  changes. The bookmarks toolbar is always visible.
- `shared/` is available for additional read-only workspace data.

Bookmark entries use this format:

```json
[
  {
    "title": "AWS Client VPN user guide",
    "url": "https://docs.aws.amazon.com/vpn/latest/clientvpn-user/what-is.html"
  }
]
```

The tracked `examples/demo/dev` directory is a safe example workspace:

```console
nix develop -c tart clone vm-vpn-macos-compact demo-dev
nix develop -c tart run demo-dev \
  --dir="$PWD/examples/demo/dev:ro,tag=workspace"
```

The example VPN profile is intentionally non-functional. Real VPN profiles
and credentials must not be committed.

## Validation

```console
nix develop -c bats tests/macos-image.bats
nix develop -c shellcheck macos/scripts/* scripts/ci-check
nix develop -c packer validate macos/packer
nix develop -c scripts/ci-check
```

The generated VM is left stopped after a successful build. Build failures also
use a shutdown trap so a guest is not left running unattended.
