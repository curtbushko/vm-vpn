# macOS VPN Workspace Configs

Run isolated macOS VPN workspaces from host-managed configurations. Each
`<product>/<environment>` config supplies its own AWS VPN profile, Firefox
bookmarks, and shared files. Multiple configs can run concurrently; VM images
and clones are managed internally.

## Fresh-Mac quick start

Start with an Apple Silicon Mac and at least 65 GB of free disk space. Initial
setup downloads the Cirrus Labs Sequoia source and builds the shared runtime;
it can take a while and uses substantial network bandwidth. Config clones need
additional space as they diverge from the shared image. Rosetta is not used.

Install Determinate Nix with the official Determinate Systems installer:

```console
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix | sh -s -- install macos
```

Open a new terminal and confirm Nix is available:

```console
nix --version
```

If another Nix distribution is already installed, use the Determinate Systems
migration guide instead of installing over it:
<https://docs.determinate.systems/guides/migrating-from-upstream-nix/>.

Install `direnv` and enable its Zsh hook:

```console
nix profile install nixpkgs#direnv
printf '%s\n' 'eval "$(direnv hook zsh)"' >> ~/.zshrc
exec zsh
```

Clone the repository and approve its development environment:

```console
git clone <repository-url>
cd vm-vpn
direnv allow
task doctor
```

Build the shared runtime once. macOS may request Local Network permission for
Packer or Tart; grant it so provisioning can communicate with the guest.

```console
task setup
```

Then create, populate, validate, and start the included example:

```console
task create -- demo dev
task seed -- demo dev
task validate -- demo dev
task start -- demo dev
```

The demo VPN profile is intentionally non-functional, so it cannot establish a
real VPN connection. It still lets you inspect the VM, Firefox bookmarks,
Ghostty, AWS VPN Client, and mounted files. Replace the demo profile with a real
AWS Client VPN profile when testing connectivity.

## Returning-user workflow

After the one-time setup, the everyday workflow is:

```console
task list
task start -- demo dev
task logs -- demo dev
task stop -- demo dev
```

Use `task status -- demo dev` when a config does not start as expected. Use
`task logs -- demo dev` in another terminal to stream the guest bootstrap's
standard output and errors. Run `task help` for the complete command guide;
bare `task` shows the same guide.

## Config locations and format

Configs live outside the repository:

```text
~/.config/vm-vpn/<product>/<environment>/
├── appearance.json
├── vpn/
│   ├── corporate.ovpn
│   └── production.ovpn
├── bookmarks/
│   └── bookmarks.json
└── shared/
```

- Every `vpn/*.ovpn` file is imported through the AWS VPN Client CLI. Its
  filename without `.ovpn` becomes the profile name, so `corporate.ovpn`
  appears as `corporate`. Profile filenames may contain letters, numbers,
  dots, underscores, and hyphens.
- `bookmarks/bookmarks.json` defines its Firefox bookmark toolbar entries and
  starts with two placeholder entries to edit or replace.
- `appearance.json` sets `wallpaperColor` to a six-digit hex color. New configs
  use blue for `dev`, amber for `staging`, red for `prod`, purple for
  `awsgov-prod`, orange for `preprod`, teal for `hybridtest`, and slate for
  other environments. Edit the generated value to override it.
- `shared/` contains other files that should be mounted read-only.

Bookmark entries use this format:

```json
[
  {
    "title": "Company documentation",
    "url": "https://docs.example.com/"
  },
  {
    "title": "Service dashboard",
    "url": "https://dashboard.example.com/"
  }
]
```

Product and environment names accept lowercase letters, numbers, and internal
hyphens. Use `task path -- <product> <environment>` to print a config's exact
host path.

## Create and validate a config

Create an empty config without creating a VM:

```console
task create -- <product> <environment>
task create -- demo dev
```

Add its VPN profile, bookmarks, and shared files, then check readiness:

```console
task validate -- <product> <environment>
task validate -- demo dev
```

A missing VPN profile is reported as `missing` but does not invalidate an
otherwise well-formed config. Invalid or missing bookmark JSON prevents the
config from starting.

The repository includes safe example files for `demo/dev`:

```console
task seed -- demo dev
```

Create `demo/dev` before seeding it. The example VPN profile is intentionally
non-functional. Never commit actual VPN profiles, private keys, passwords, or
credentials.

## List and inspect configs

```console
task list
task status -- demo dev
```

`task list` reports configs rather than Tart inventory:

```text
CONFIG        STATE        VPN      BOOKMARKS
demo/dev      stopped      present  valid
demo/staging  not-created  present  valid
demo/prod     not-created  missing  valid
```

The runtime state is `not-created` until a config is started for the first
time. Internal image and clone names are deliberately hidden.

## Start multiple configs

Start any or all configs from separate terminal tabs:

```console
task start -- <product> <environment>
task start -- demo dev
task start -- demo staging
task start -- demo prod
```

The three configs run concurrently in separate VMs. On first start, the command
creates that config's hidden runtime from the shared image. Later starts reuse
it so macOS and application state persist.

Each config mounts only its own
`~/.config/vm-vpn/<product>/<environment>` directory read-only at
`/Volumes/My Shared Files/workspace`. At guest login, the runtime bootstrap:

- Imports every mounted `vpn/*.ovpn` file through `aws-vpn-client`, using the
  filename without `.ovpn` as its profile name. Only profiles previously
  managed by this bootstrap are removed when mounted files change; manual AWS
  VPN Client profiles are left alone.
- Replaces Firefox managed bookmarks with the mounted `bookmarks.json` entries.
- Generates a VM-local wallpaper asset from the mounted `appearance.json` color.
  It does not change the macOS wallpaper preference because that preference can
  synchronize through an Apple account and affect another Mac.
- Makes `shared/` available through the read-only workspace mount.

This prevents VPN profiles and bookmarks from accumulating across configs.
Host-file changes take effect the next time that config starts.

Firefox starts on a blank page, keeps the bookmarks toolbar visible, omits its
default import bookmark, and is configured as the default browser in the base
image.

While a config is running, stream the most recent guest bootstrap output and
continue following both its normal and error logs with:

```console
task logs -- demo dev
```

Press Ctrl-C to stop following the logs; this does not stop the VM.

Stop one config or all running configs without deleting their state:

```console
task stop -- demo dev
task stop-all
```

## Delete a config

```console
task delete -- <product> <environment>
task delete -- demo dev
```

`delete` permanently removes the host config and its hidden runtime clone. It
does not use a trash directory and cannot recover the deleted files. Other
configs and the shared image are unaffected.

## Setup and maintenance commands

These commands manage project internals and are not part of the everyday config
workflow:

The checked-in `.envrc` automatically supplies Task, Packer, Tart, tests,
formatters, and shell tools whenever the repository is entered. Commands do not
need a `nix develop` prefix. `task setup` is idempotent and builds the shared
runtime only when it is missing.

```console
task setup
task clean
task image:build
task image:status
task doctor
task check
task help
```

- `setup` ensures the shared runtime image exists.
- `clean` permanently deletes hidden runtime clones whose configs no longer
  exist.
- `image:build` invokes the image build directly and refuses to overwrite an
  existing image.
- `image:status` shows diagnostic details about the shared image.
- `doctor` verifies tools provided by the development shell.
- `check` runs tests, lint, formatting, and flake validation.

The internal appliance contains Firefox, Ghostty, and AWS VPN Client. It uses
two virtual CPUs, 6 GB of memory, and a sparse 50 GB raw disk that has occupied
about 28 GB after provisioning. Its Cirrus Labs Sequoia vanilla source is about
24 GB compressed. Rosetta is not used.

Image creation provisions a temporary `vm-vpn-base-building` VM and verifies
the installed applications and three-item Dock before publishing it as
`vm-vpn-base`. A failed or interrupted customization therefore cannot be
mistaken for a ready base image. `task setup` replaces an older, unverified
base, while `task start` refuses to clone from one.

Real AWS authentication, SAML browser handoff, DNS, private routes, and internal
resources still require an interactive acceptance test with a real profile.
The complete workflow also needs a fresh-machine acceptance run on a second Mac
before it should be considered fully portable.
