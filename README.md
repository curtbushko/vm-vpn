# macOS VPN Workspace VM

This project builds a small, reusable macOS Sequoia appliance for Tart. The
guest contains Firefox, Ghostty, and AWS VPN Client. Nix remains the host-side
development environment and supplies Packer, Tart, shell tooling, and tests.

The appliance uses two virtual CPUs, 6 GB of memory, and the Cirrus Labs
`macos-sequoia-vanilla` image. The inherited 50 GB raw disk remains sparse on
the host. Packer removes its trailing recovery partition, while SIP and
authenticated-root protection remain enabled.

## Clean-host requirements

A second person can build the appliance from scratch when their host meets all
of these requirements:

- An Apple Silicon Mac. Intel Macs, Linux hosts, and non-Apple virtualization
  hosts are not supported.
- Nix with flakes enabled. Nix supplies every other host-side build tool.
- Internet access to GitHub, GHCR, Homebrew, Mozilla, Ghostty, and AWS download
  endpoints.
- About 24 GB of network transfer for the compressed Cirrus vanilla image.
- About 28 GB of host storage for the built golden image, plus storage for
  changes made inside each cloned VM.

macOS may ask for Local Network permission when Tart or Packer first connects
to a guest. That permission must be granted for SSH bootstrap and guest
provisioning to work. No Rosetta installation is required.

From a new checkout:

```console
git clone <repository-url>
cd vm-vpn
nix develop
packer init macos/packer
macos/scripts/build-image vm-vpn-macos-compact
```

The build refuses to overwrite an existing VM named
`vm-vpn-macos-compact`. Stop, rename, or deliberately remove that existing
artifact before rebuilding it.

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

Multiple independent workspaces can be cloned from the same golden image:

```console
nix develop -c tart clone vm-vpn-macos-compact vault-dev
nix develop -c tart clone vm-vpn-macos-compact consul-lab

nix develop -c tart run vault-dev \
  --dir="$HOME/.config/vm-vpn/vault/dev:ro,tag=workspace"

nix develop -c tart run consul-lab \
  --dir="$HOME/.config/vm-vpn/consul/lab:ro,tag=workspace"
```

Stop them independently:

```console
nix develop -c tart stop vault-dev
nix develop -c tart stop consul-lab
```

Each clone has its own writable VM disk. APFS copy-on-write avoids immediately
duplicating every block from the golden image, but each VM consumes additional
host storage as it changes.

The repository does not currently provide a single lifecycle command for
creating, starting, stopping, or deleting named macOS workspaces. Operators use
`tart clone`, `tart run`, and `tart stop` directly. Real AWS VPN authentication,
SAML browser handoff, DNS, and private routes require an interactive acceptance
test with a real profile.

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

The workflow has been built and verified on the development host, but it has
not yet completed a fresh-machine acceptance run on a second Mac. Perform that
acceptance run before treating the image pipeline as fully portable.
