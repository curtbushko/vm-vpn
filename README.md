# macOS VPN Workspace VMs

This repository builds one reusable Tart base image and creates persistent VM
instances from it. Each instance contains Firefox, Ghostty, and AWS VPN Client,
but loads its bookmarks, VPN profile, and shared files from a separate host
directory whenever it starts.

For example, these instances can run concurrently from the same base:

| Configuration | Tart instance | Host settings |
| --- | --- | --- |
| `demo/dev` | `vm-vpn-demo-dev` | `~/.config/vm-vpn/demo/dev` |
| `demo/staging` | `vm-vpn-demo-staging` | `~/.config/vm-vpn/demo/staging` |
| `demo/prod` | `vm-vpn-demo-prod` | `~/.config/vm-vpn/demo/prod` |

The appliance runs on an Apple Silicon Mac with two virtual CPUs, 6 GB of
memory, and a sparse 50 GB raw disk. The current build is based on the
approximately 24 GB compressed Cirrus Labs Sequoia vanilla image and has
occupied about 28 GB after provisioning. Tart clones may require additional
host storage as their files diverge from the base. Rosetta is not used.

## 1. Install Determinate Nix on macOS

This project assumes an Apple Silicon Mac with Determinate Nix. Install it with
the official Determinate Systems installer:

```console
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix | sh -s -- install macos
```

Open a new terminal and verify the installation:

```console
nix --version
```

Determinate Nix enables flakes and configures the Nix daemon. If another Nix
distribution is already installed, follow the Determinate Systems migration
guide instead of installing over it:
<https://docs.determinate.systems/guides/migrating-from-upstream-nix/>.

## 2. Enable the development environment with direnv

Install `direnv` through Nix:

```console
nix profile install nixpkgs#direnv
```

For the default macOS Zsh shell, add its hook to `~/.zshrc`:

```sh
eval "$(direnv hook zsh)"
```

Open a new terminal, clone this repository, enter it, and approve the checked-in
environment once:

```console
git clone <repository-url>
cd vm-vpn
direnv allow
```

The `.envrc` loads the flake automatically. Task, Packer, Tart,
tests, formatters, and shell tools are then on `PATH` whenever this directory is
entered. The commands below deliberately contain no `nix develop` prefix.

Verify the command environment:

```console
task doctor
```

## 3. Build the reusable base

```console
task build
```

`task build` wraps Packer and Tart. It downloads the Cirrus image, builds
`vm-vpn-base`, installs and configures the applications, seals the image, and
stops it. It refuses to overwrite an existing base.

The first build may cause macOS to request Local Network permission for Packer
or Tart. Grant it so provisioning can communicate with the guest.

## 4. Create VM instances

Create one persistent instance for each product and environment:

```console
task create -- demo dev
task create -- demo staging
task create -- demo prod
```

`create` clones `vm-vpn-base` and creates the corresponding protected settings
directory. It does not rebuild macOS. Product and environment names may contain
lowercase letters, numbers, and internal hyphens.

The host directory format is:

```text
~/.config/vm-vpn/<product>/<environment>/
├── vpn/
│   └── profile.ovpn
├── bookmarks/
│   └── bookmarks.json
└── shared/
```

- Place the environment's AWS Client VPN profile at `vpn/profile.ovpn`.
- Define Firefox bookmarks in `bookmarks/bookmarks.json`.
- Put other files that should be visible read-only in `shared/`.

Bookmarks use this format:

```json
[
  {
    "title": "AWS Client VPN user guide",
    "url": "https://docs.aws.amazon.com/vpn/latest/clientvpn-user/what-is.html"
  }
]
```

To populate `demo/dev` with tracked, non-secret examples after creating it:

```console
task seed -- demo dev
```

The example VPN profile is intentionally non-functional. Never commit actual
VPN profiles, private keys, passwords, or credentials.

## 5. Start multiple VMs

Start any or all instances:

```console
task start -- demo dev
task start -- demo staging
task start -- demo prod
```

Each `start` command owns its Tart window and remains attached while that VM is
running, so issue concurrent starts from a separate terminal or terminal tab.

They run concurrently as `vm-vpn-demo-dev`, `vm-vpn-demo-staging`, and
`vm-vpn-demo-prod`. Each start mounts only that instance's
`~/.config/vm-vpn/<product>/<environment>` directory read-only at
`/Volumes/My Shared Files/workspace`.

At guest login, the runtime bootstrap:

- Replaces the AWS profile at
  `~/.config/AWSVPNClient/OpenVpnConfigs/workspace.ovpn` with the mounted
  `vpn/profile.ovpn`.
- Replaces Firefox managed bookmarks with the mounted `bookmarks.json` entries.
- Makes `shared/` available inside the read-only workspace mount.

This keeps environment data out of the reusable base and prevents VPN profiles
or bookmarks from accumulating across configurations. Changes made to the host
files take effect the next time that VM starts. Each cloned VM retains its own
macOS and application state between starts.

## VM lifecycle commands

```console
task build
task create -- <product> <environment>
task start -- <product> <environment>
task stop -- <product> <environment>
task delete -- <product> <environment>
task status -- <product> <environment>
task list
task stop-all
```

- `build` creates the reusable `vm-vpn-base` image.
- `create` clones the base and initializes its host configuration if needed.
- `start` runs one clone with its matching configuration mounted read-only.
- `stop` stops one instance without deleting it.
- `delete` stops and deletes one Tart clone. Its host configuration is
  intentionally preserved so another clone can reuse it.
- `status` reports one instance's Tart state.
- `list` shows the runnable `<product>/<environment>` host configurations and
  their paths. It does not expose the Tart base or clone inventory.
- `stop-all` stops all instances whose names begin with `vm-vpn-`, excluding the
  base.

## Other wrapper commands

```console
task seed -- demo dev
task config-path -- <product> <environment>
task doctor
task check
task help
```

`task check` runs the test, lint, formatting, and flake quality gates using tools
provided by the automatically loaded development shell.

Run `task help` for explanations of every command and argument. Running bare
`task` shows the same guide because `help` is the default task. In commands that
accept a product and environment, `--` tells Task to forward the remaining
values as arguments.

Real AWS authentication, SAML browser handoff, DNS, private routes, and internal
resources still require an interactive acceptance test with a real profile.
The complete workflow also needs a fresh-machine acceptance run on a second Mac
before it should be considered fully portable.
