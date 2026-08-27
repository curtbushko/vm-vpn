# VPN Workspace VM Design

## Purpose

Build a declarative, reproducible system for running multiple isolated graphical NixOS VMs on macOS, with one VM per VPN workspace.

Each VM exists to isolate:

- VPN routing
- DNS
- browser sessions
- SAML authentication
- customer-specific certificates
- customer-specific internal network access
- customer-specific browser state

Source code, Git repositories, and primary development tooling remain on the macOS host.

The VM is primarily a network, browser, and identity boundary.

The system is managed from a single Nix repository and uses Tart as the VM runtime.

All commands documented here are assumed to be run:

1. from the repository root
2. inside the repository's Nix development shell

Do not add instructions that require callers to locate helper scripts manually or invoke commands from outside the repository.

---

# Goals

The implementation must provide:

1. One independently routable VM per `PRODUCT` + `ENVIRONMENT`.
2. A graphical NixOS guest suitable for browser-heavy work.
3. AWS Client VPN connectivity with interactive SAML approval.
4. Strong visual differentiation between simultaneously running VMs.
5. Declarative configuration from one Nix repository.
6. Persistent browser and user-session state.
7. Local-only handling of sensitive VPN and internal-network data.
8. Sensitive workspace data must never be committed to or managed by Git.
9. Simple lifecycle commands for creating, updating, starting, stopping, and inspecting VMs.
10. A design that remains usable with roughly ten VMs.
11. A predictable naming scheme derived from `PRODUCT` and `ENVIRONMENT`.

---

# Non-Goals

The initial implementation does not need to:

- move source code into the VM
- duplicate the host development environment inside every VM
- provide transparent host routing into every VPN
- replace Tart with a custom hypervisor
- automatically approve SAML authentication
- store sensitive VPN configuration in the Nix store
- make browser state reproducible
- make each VM completely stateless

---

# Core Identity Model

Every VM has exactly two required identity dimensions:

```text
PRODUCT
ENVIRONMENT
```

Example:

```text
PRODUCT=consul
ENVIRONMENT=customer-a
```

The canonical VM name is:

```text
${PRODUCT}-${ENVIRONMENT}
```

Example:

```text
consul-customer-a
```

The canonical filesystem identity is:

```text
${PRODUCT}/${ENVIRONMENT}
```

The ordering must remain consistent everywhere:

```text
PRODUCT first
ENVIRONMENT second
```

Do not introduce alternate forms such as:

```text
customer-a-consul
consul_customer_a
Consul-customer-a
cust-a-consul
```

unless a specific external system requires it.

---

# Naming Rules

## PRODUCT

`PRODUCT` must be:

- lowercase
- stable
- short
- filesystem-safe
- hostname-safe
- hyphenated if multiple words are unavoidable

Examples:

```text
consul
vault
nomad
boundary
platform-api
```

## ENVIRONMENT

`ENVIRONMENT` must be:

- lowercase
- stable
- filesystem-safe
- hostname-safe
- hyphenated where needed

Examples:

```text
customer-a
customer-b
staging
production
prod-us-east
lab
```

## Derived Names

The implementation should derive names rather than store duplicated strings.

Conceptually:

```bash
VM_NAME="${PRODUCT}-${ENVIRONMENT}"
VM_PATH="${PRODUCT}/${ENVIRONMENT}"
```

The same identity should be used for:

- Tart VM name
- Nix configuration name
- hostname
- persistent state directory
- generated artifacts
- logs
- browser profile name
- desktop identity
- terminal identity
- status output

---

# Human-Facing Identity

Machine identity and human-facing labels are related but distinct.

Required invariant:

```text
machine identity  = PRODUCT + ENVIRONMENT
filesystem path   = PRODUCT / ENVIRONMENT
human label       = DISPLAY_NAME
```

Example:

```nix
{
  product = "consul";
  environment = "customer-a";

  identity.displayName = "Consul — Customer A";
}
```

`DISPLAY_NAME` must never be used as a filesystem or machine identifier.

---

# Identity Data Location

Visual identity data is non-sensitive configuration and belongs in the Git repository.

This includes:

- `PRODUCT`
- `ENVIRONMENT`
- `DISPLAY_NAME`
- product Nerd Font icon
- environment Nerd Font icon
- product color family
- environment accent color
- background color
- foreground color
- wallpaper-generation inputs
- browser theming rules
- terminal theming rules
- desktop theming rules

This data must not live beside local VPN profiles or bookmarks.

The repository/local-data boundary is:

```text
Git repository
  PRODUCT
  ENVIRONMENT
  DISPLAY_NAME
  icons
  colors
  wallpaper rules
  browser theming rules
  terminal theming rules
  desktop theming rules

~/.local/share/vm-vpn/
  VPN profile
  bookmarks/internal URLs
  certificates
  private keys
  other sensitive connectivity data
```

Visual identity should remain reproducible when the repository is cloned to another machine.

Sensitive connectivity data should not travel with the repository.

---

# Identity Configuration Layers

Visual identity is composed from three declarative layers:

```text
PRODUCT metadata
      +
ENVIRONMENT metadata
      +
workspace-specific overrides
      ↓
resolved identity
```

The resolved identity is then consumed by:

```text
wallpaper
desktop
browser
terminal
shell prompt
window chrome
VM status output
```

Prefer deriving these surfaces from one resolved identity object rather than configuring each application independently.

---

# Product Identity Data

Product-level identity belongs under:

```text
products/${PRODUCT}.nix
```

Example:

```nix
{
  icon = "󰛳";

  colors = {
    family = "purple";
  };
}
```

Product-level configuration should define stable traits shared across environments for the same product.

Examples include:

- product icon
- product color family
- product-specific visual defaults
- optional product-specific wallpaper elements

Do not assign the final workspace accent solely from the product if that would make environments too easy to confuse.

---

# Environment Identity Data

Environment-level identity belongs under:

```text
environments/${ENVIRONMENT}.nix
```

Example:

```nix
{
  icon = "󰀄";

  colors = {
    accent = "#7C3AED";
    background = "#181520";
    foreground = "#FFFFFF";
  };
}
```

Environment-level configuration should define traits used to distinguish environment contexts.

Examples include:

- environment icon
- accent color
- background color
- foreground color
- optional environment-specific visual cues

---

# Workspace Identity Overrides

Workspace-specific overrides belong under:

```text
workspaces/${PRODUCT}/${ENVIRONMENT}.nix
```

Example:

```nix
{
  product = "consul";
  environment = "customer-a";

  identity = {
    displayName = "Consul — Customer A";
  };
}
```

Use workspace overrides only when the specific `PRODUCT` + `ENVIRONMENT` combination requires something different from the product/environment defaults.

Do not duplicate values in the workspace file when they can be derived from product or environment metadata.

---

# Resolved Identity

The implementation should produce one resolved identity object.

Conceptually:

```nix
{
  product = "consul";
  environment = "customer-a";
  vmName = "consul-customer-a";

  displayName = "Consul — Customer A";

  icons = {
    product = "󰛳";
    environment = "󰀄";
    vpnConnected = "󰌾";
    vpnDisconnected = "󰌿";
  };

  colors = {
    family = "purple";
    accent = "#7C3AED";
    background = "#181520";
    foreground = "#FFFFFF";
  };
}
```

Every visual integration should consume this resolved identity.

Avoid defining separate copies of color/icon values for:

- browser
- terminal
- wallpaper
- desktop
- status output

---

# Wallpaper Generation Data

Prefer generating wallpapers from resolved identity data instead of storing one hand-authored wallpaper per workspace.

Inputs should include:

```text
PRODUCT
ENVIRONMENT
VM_NAME
DISPLAY_NAME
product icon
environment icon
accent
background
foreground
```

The generated wallpaper itself may enter the Nix store because these inputs are explicitly non-sensitive.

Do not include sensitive local-only values such as internal URLs, VPN endpoints, or private hostnames in wallpaper-generation inputs.

---

# Browser Theme Data

Browser visual theming belongs in the declarative repo-managed identity system.

Browser theme generation may consume:

```text
DISPLAY_NAME
product icon
environment icon
accent
background
foreground
```

Sensitive browser content does not belong in this identity configuration.

In particular:

```text
browser theme/profile identity -> Git/Nix
bookmarks/internal URLs        -> local-only runtime data
```

The browser should combine both at runtime:

```text
declarative visual identity
          +
runtime-loaded local bookmarks
          ↓
workspace browser experience
```

---

# Terminal Theme Data

Terminal theme data belongs in the repository and should consume the resolved identity.

This includes:

- accent color
- background color
- foreground color
- product icon
- environment icon
- prompt label

Example:

```text
󰛳 consul / 󰀄 customer-a
```

Terminal theme data must not depend on sensitive local-only workspace values.

---

# Visual Identity System

Each VM must be visually obvious.

The goal is to make operating in the wrong customer/environment difficult.

Visual identity is derived from `PRODUCT` and `ENVIRONMENT`.

A VM identity should support at least:

```nix
identity = {
  displayName = "Consul — Customer A";

  productIcon = "...";
  environmentIcon = "...";

  colors = {
    primary = "#...";
    background = "#...";
    foreground = "#...";
  };
};
```

Nerd Font glyphs may be used for product and environment icons.

Prefer semantic icon configuration over scattering raw glyphs throughout modules.

Example:

```nix
icons = {
  product = "󰛳";
  environment = "󰀄";
  vpnConnected = "󰌾";
  vpnDisconnected = "󰌿";
};
```

The same identity must carry through as many surfaces as practical:

- wallpaper
- desktop panel
- lock screen
- terminal theme
- shell prompt
- browser profile name
- browser theme/accent
- browser start page
- window decoration
- hostname display
- VM status output

A canonical visual label should be derivable:

```text
󰛳 consul / 󰀄 customer-a
```

---

# Product vs Environment Identity

Prefer a two-level visual system.

`PRODUCT` determines the general visual family.

`ENVIRONMENT` determines the specific variant.

For example:

```text
PRODUCT=consul
  -> purple family

ENVIRONMENT=customer-a
  -> violet accent

ENVIRONMENT=customer-b
  -> blue-violet accent
```

The exact palette is configuration, not hard-coded application behavior.

Applications should consume the shared identity palette rather than independently selecting colors.

---

# Wallpaper

The wallpaper is functional UI.

It should prominently identify the current workspace.

A generated wallpaper should include at least:

```text
PRODUCT
ENVIRONMENT
VM_NAME
```

It may also include:

```text
product icon
environment icon
VPN state hint
```

Example conceptual layout:

```text
┌─────────────────────────────────────────────┐
│                                             │
│                 󰛳 CONSUL                    │
│              󰀄 CUSTOMER-A                   │
│                                             │
│          consul-customer-a                  │
│                                             │
└─────────────────────────────────────────────┘
```

Prefer generating wallpapers from identity data instead of manually maintaining one image per VM.

Do not include sensitive internal URLs, VPN endpoints, private hostnames, credentials, or certificate information in wallpapers.

---

# Browser Identity

The browser is a primary workload inside the VM.

The browser configuration should consume workspace identity.

At minimum, configure:

- browser profile name
- visual theme/accent where practical
- bookmarks mechanism
- start page mechanism
- trusted certificates mechanism

Example profile label:

```text
󰛳 Consul / 󰀄 Customer A
```

The browser should visibly reinforce the workspace identity even when the desktop wallpaper is not visible.

Browser state is persistent and is not expected to be fully reproducible.

Persistent browser state may include:

- SAML cookies
- SSO sessions
- browser history
- browser cache
- local storage
- extension state
- client certificate selections

Treat the persistent VM disk as sensitive because it will accumulate internal network information.

---

# Terminal Identity

The terminal should use the same visual identity.

At minimum, expose:

- `PRODUCT`
- `ENVIRONMENT`
- `VM_NAME`
- product icon
- environment icon
- identity accent

Example prompt prefix:

```text
󰛳 consul / 󰀄 customer-a
```

or:

```text
[consul/customer-a]
```

The exact shell prompt implementation is not prescribed.

---

# VM Runtime

Use Tart as the VM runtime on macOS.

Tart should remain a relatively thin execution layer.

The Nix repository is the source of truth for:

- VM identity
- NixOS configuration
- graphical environment
- browser configuration
- common packages
- identity theme
- VPN software installation
- runtime sensitive-data plumbing
- host share declarations
- lifecycle metadata

Tart is responsible for:

- VM execution
- VM persistence
- VM cloning/base images where useful
- presenting the graphical guest
- host/guest virtualization primitives

Do not make Tart configuration the primary source of truth for workspace behavior.

The public lifecycle command interface should hide direct Tart invocations during normal use.

For example:

```bash
vm up consul customer-a
vm down consul customer-a
vm rebuild consul customer-a
vm status consul customer-a
vm list
```

---

# Tart Backend Boundary

Keep Tart-specific behavior isolated from higher-level workspace logic.

Conceptually:

```text
vm command
    ↓
workspace resolver
    ↓
Tart backend
```

Higher-level lifecycle logic should depend on operations conceptually equivalent to:

```text
exists(workspace)
create(workspace)
start(workspace)
stop(workspace)
destroy(workspace)
status(workspace)
share(workspace, hostPath, guestPath)
present(workspace)
```

Tart-specific commands must remain isolated from:

- workspace identity resolution
- visual identity
- local sensitive-data discovery
- browser configuration
- VPN configuration
- NixOS guest configuration

Prefer a structure such as:

```text
lib/
  tart.nix
```

or an equivalent implementation-language structure.

---

# Guest Operating System

The guest is graphical NixOS.

The guest must provide:

- graphical desktop
- browser
- terminal
- VPN software
- SAML-capable authentication flow
- certificate trust configuration
- persistent user profile
- runtime secret consumption
- SSH access if useful for debugging or host integration

The desktop environment is an implementation choice.

Prefer a desktop that is:

- lightweight
- well-supported by NixOS
- easy to theme declaratively
- stable under virtualization
- suitable for browser-first use

---

# AWS Client VPN and SAML

VPN authentication includes SAML and requires interactive approval.

The system must not attempt to bypass or automate approval.

The intended flow is:

```text
start VM
    ↓
open/launch VPN connection
    ↓
browser/SAML authentication begins
    ↓
user approves connection
    ↓
VPN becomes active
    ↓
browser and terminal use guest-local routing/DNS
```

The implementation must validate the exact AWS Client VPN / OpenVPN-compatible SAML mechanism chosen for NixOS.

Do not assume that a plain OpenVPN invocation is sufficient for every profile.

The selected VPN client must support the actual interactive authentication flow in use.

---

# Network Isolation

Each VM owns its own:

- routing table
- DNS configuration
- VPN tunnel
- browser network context
- internal address space

This is the primary reason for using separate VMs.

Overlapping customer networks must be able to coexist.

Example:

```text
consul-customer-a
  10.0.0.0/8 via VPN A

consul-customer-b
  10.0.0.0/8 via VPN B
```

These must not conflict because the routes live in independent guests.

The host should not be modified with customer VPN routes.

---

# Host Responsibilities

The macOS host remains the primary development workstation.

Keep on the host:

- source code
- Git repositories
- Neovim/editor
- general CLI tooling
- normal shell environment
- local build workflow unless a workload specifically requires the VPN guest

The VM exists primarily for:

- browser work
- SAML
- VPN
- DNS
- customer network context
- network-specific troubleshooting
- occasional guest-side CLI tools

---

# Host Filesystem Sharing

Host source code may be exposed to the guest using Tart-supported host directory sharing such as VirtioFS.

The share should be explicitly configured.

Do not expose the entire host home directory by default.

Prefer narrowly scoped paths.

Example conceptual mapping:

```text
macOS:
  ~/src

guest:
  /mnt/host/src
```

The exact path should be configurable.

The shared source tree is not the authoritative location for VM state.

Do not place browser state, secrets, VPN runtime files, or guest system state in host source directories.

---

# Declarative vs Persistent State

The system must explicitly distinguish declarative machine state from mutable session state.

## Declarative

Managed through Nix:

- OS
- packages
- desktop configuration
- browser installation
- browser policy mechanism
- VPN software
- trust-store mechanism
- shell
- terminal
- icons
- colors
- wallpaper generation
- hostname
- identity
- secret plumbing
- service configuration

## Persistent

Stored on the per-VM persistent disk:

- browser profile
- SAML sessions
- cookies
- cache
- browser local storage
- user-selected browser state
- runtime application state
- other state that should survive reboot

A rebuild must not normally destroy persistent browser/session state.

---

# Sensitive Information

Customer name and environment name are explicitly NOT considered sensitive for this design.

The following ARE sensitive and must be treated as local-only data:

- VPN profile contents
- VPN endpoints if present in profiles
- internal URLs
- internal hostnames
- private network topology details
- private CA material where applicable
- client certificates where applicable
- private keys
- tokens
- authentication material

These values must not be committed to Git, even in encrypted form.

The threat model for this design assumes that sending these values to a Git remote, CI system, repository host, or other external storage is itself an unnecessary risk.

---

# Local-Only Workspace Data

Sensitive workspace data lives outside the repository in an XDG-style local data directory.

The canonical root is:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/vm-vpn
```

On a default system this resolves to:

```text
~/.local/share/vm-vpn
```

Workspace-local sensitive data must preserve the canonical identity layout:

```text
${PRODUCT}/${ENVIRONMENT}
```

Example:

```text
~/.local/share/vm-vpn/
└── consul/
    └── customer-a/
        ├── vpn/
        │   └── profile.ovpn
        ├── bookmarks/
        │   └── bookmarks.json
        ├── certs/
        └── state/
```

The repository decides where sensitive data belongs.

The local filesystem contains the sensitive data.

Git never owns the contents.

Required invariant:

```text
Git = code + non-sensitive identity
Local workspace data = sensitive connectivity data
VM runtime = runtime-accessible copies/materialization
```

The sensitive data root must not live inside the repository, even if `.gitignore` would exclude it.

Do not rely on `.gitignore` as a security boundary.

---

# Local Data Root

The lifecycle tooling should expose one canonical variable:

```bash
VM_VPN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/vm-vpn"
```

From that derive:

```bash
WORKSPACE_DATA="${VM_VPN_DATA}/${PRODUCT}/${ENVIRONMENT}"
```

All sensitive local workspace paths must derive from this root.

Examples:

```bash
VPN_PROFILE="${WORKSPACE_DATA}/vpn/profile.ovpn"
BOOKMARKS_FILE="${WORKSPACE_DATA}/bookmarks/bookmarks.json"
CERTS_DIR="${WORKSPACE_DATA}/certs"
LOCAL_STATE_DIR="${WORKSPACE_DATA}/state"
```

Do not duplicate these path rules independently across scripts.

The implementation should centralize path derivation.

---

# Local Data Permissions

Workspace-sensitive data must use restrictive permissions.

Recommended defaults:

```text
workspace directory: 0700
vpn directory:       0700
bookmarks directory: 0700
certs directory:     0700
state directory:     0700
sensitive files:     0600
```

The tooling should repair overly broad permissions where safe, or fail with a clear warning where automatic repair would be risky.

Do not make sensitive workspace files world-readable or group-readable by default.

---

# Local Data Creation

The CLI must provide a first-class way to create the correct local directory structure.

Use:

```bash
vm init PRODUCT ENVIRONMENT
```

Example:

```bash
vm init consul customer-a
```

`vm init` must:

1. validate that `PRODUCT` exists
2. validate that `ENVIRONMENT` exists
3. validate that the workspace combination is configured in the repository
4. derive the canonical workspace data path
5. create the required local directories
6. set restrictive permissions
7. avoid overwriting existing sensitive files
8. print the canonical paths the user should populate

Expected structure:

```text
~/.local/share/vm-vpn/${PRODUCT}/${ENVIRONMENT}/
├── vpn/
├── bookmarks/
├── certs/
└── state/
```

`vm init` may create an empty bookmarks file or schema example only if doing so does not risk overwriting user data.

It should not create a fake VPN profile.

Example output:

```text
Initialized local workspace data:

~/.local/share/vm-vpn/consul/customer-a/

VPN profile:
  ~/.local/share/vm-vpn/consul/customer-a/vpn/profile.ovpn

Bookmarks:
  ~/.local/share/vm-vpn/consul/customer-a/bookmarks/bookmarks.json

Certificates:
  ~/.local/share/vm-vpn/consul/customer-a/certs/
```

---

# Import Commands

The CLI should provide convenience commands for moving sensitive files into canonical locations.

Required initial command:

```bash
vm import-vpn PRODUCT ENVIRONMENT SOURCE
```

Example:

```bash
vm import-vpn consul customer-a ~/Downloads/client.ovpn
```

This must copy the supplied profile to:

```text
~/.local/share/vm-vpn/consul/customer-a/vpn/profile.ovpn
```

and set restrictive permissions.

The import must not modify the source file.

If the destination already exists, do not silently overwrite it.

Either:

- fail with a clear message, or
- require an explicit overwrite flag

Prefer safe failure by default.

Also provide:

```bash
vm import-bookmarks PRODUCT ENVIRONMENT SOURCE
vm import-cert PRODUCT ENVIRONMENT SOURCE
```

Example:

```bash
vm import-bookmarks consul customer-a ~/Downloads/bookmarks.json
vm import-cert consul customer-a ~/Downloads/client.pem
```

`vm import-cert` should preserve the source filename unless the implementation has a stronger schema for certificate roles.

Future variants may add explicit certificate roles such as:

```bash
vm import-cert consul customer-a --ca ca.pem
vm import-cert consul customer-a --client-cert client.pem
vm import-cert consul customer-a --client-key client.key
```

Do not add role complexity until it is needed.

---

# Local-Only Data and Git

The repository must contain only:

- Nix code
- lifecycle tooling
- non-sensitive workspace identity
- product metadata
- environment metadata
- visual identity
- schema/validation logic
- references to expected local data

The repository must not contain:

- plaintext VPN profiles
- encrypted VPN profiles
- plaintext internal bookmarks
- encrypted internal bookmarks
- private certificate material
- encrypted private certificate material
- tokens
- authentication secrets

The design intentionally does not use Git as a transport for sensitive workspace data.

This applies even when the Git repository is private.

---

# Nix Store Secret Boundary

The core invariant is:

```text
Nix may know local sensitive file paths.
Nix must not contain plaintext sensitive values.
```

Normal Nix configuration may contain logical expectations or path metadata such as:

```nix
{
  vpn.profilePath = "/run/vpn-workspace/profile.ovpn";
  browser.runtimeBookmarksPath = "/run/vpn-workspace/bookmarks.json";
}
```

It must not contain:

```nix
vpn.profile = ''
  <plaintext sensitive VPN profile>
'';

browser.startPages = [
  "https://sensitive.internal.example"
];
```

if those values would be realized into the Nix store.

Sensitive values must be copied, mounted, or materialized at runtime from the local-only workspace data directory.

Do not use the Nix store as an intermediate transport for sensitive values.

---

# Runtime Materialization

The host-side lifecycle tooling should make required local data available to the VM without first placing plaintext contents in the Nix store.

Preferred runtime locations inside the guest are:

```text
/run/vpn-workspace/
```

or another tmpfs-backed runtime path.

Examples:

```text
/run/vpn-workspace/profile.ovpn
/run/vpn-workspace/bookmarks.json
/run/vpn-workspace/certs/
```

The exact transport may use Tart-supported file sharing, runtime copy, SSH transfer, or another mechanism that avoids Nix-store ingestion.

The implementation should choose the simplest secure mechanism.

Sensitive runtime material should disappear on guest shutdown where practical.

Persistent applications such as browsers may still retain derived sensitive state on the persistent VM disk.

---

# Browser Sensitive Configuration

Internal URLs must not be compiled into browser policies through Nix if that would place plaintext URLs in the Nix store.

Instead:

1. Nix installs and configures the browser.
2. Nix installs a runtime mechanism for sensitive browser configuration.
3. Runtime secrets provide the actual internal URLs.
4. The browser profile or start-page mechanism consumes the runtime material.

The exact mechanism may be:

- runtime-generated bookmarks
- runtime-generated browser profile fragments
- a local start page generated at login
- another implementation that avoids Nix-store leakage

The implementation should favor simplicity.

---

# Persistent Disk Security

The persistent VM disk is sensitive even when secret injection is correct.

It may contain:

- browser history
- internal URLs
- DNS names
- cookies
- SAML sessions
- cached internal pages
- downloaded files
- certificate metadata
- VPN logs
- shell history

Therefore:

- treat VM disks as sensitive artifacts
- do not publish them to public/shared registries
- do not place them in shared binary caches
- do not casually clone authenticated VM state
- ensure the host storage containing them is protected appropriately
- consider VM-level or storage-level encryption where supported and useful

Do not assume a VM disk is safe merely because the original VPN profile was runtime-injected.

---

# Repository Layout

Use a layout that keeps the two primary identity dimensions explicit.

Recommended starting point:

```text
.
├── flake.nix
├── flake.lock
│
├── lib/
│   ├── mkWorkspace.nix
│   ├── identity.nix
│   └── tart.nix
│
├── modules/
│   ├── base.nix
│   ├── desktop.nix
│   ├── browser.nix
│   ├── terminal.nix
│   ├── vpn.nix
│   ├── secrets.nix
│   ├── identity.nix
│   ├── wallpaper.nix
│   └── host-share.nix
│
├── products/
│   ├── consul.nix
│   ├── vault.nix
│   └── nomad.nix
│
├── environments/
│   ├── customer-a.nix
│   ├── customer-b.nix
│   └── lab.nix
│
├── workspaces/
│   ├── consul/
│   │   ├── customer-a.nix
│   │   └── customer-b.nix
│   └── vault/
│       └── customer-a.nix
│
└── scripts/
    └── ...
```

`products/` contains reusable product identity/defaults, including product Nerd Font icons and product-level color-family metadata.

`environments/` contains reusable environment identity/defaults, including environment Nerd Font icons and environment-level accent/background/foreground colors.

`workspaces/${PRODUCT}/${ENVIRONMENT}.nix` composes the actual workspace and contains only workspace-specific non-sensitive configuration and local-data references.

Visual identity data is Git-managed and declarative.

Sensitive VPN profiles, bookmarks/internal URLs, and certificate material remain outside the repository under the local XDG workspace data root.

The filesystem structure itself should preserve:

```text
PRODUCT / ENVIRONMENT
```

wherever workspace-specific data is stored.

---

# Workspace Definition

A workspace should be concise.

Example:

```nix
{
  product = "consul";
  environment = "customer-a";

  identity = {
    displayName = "Consul — Customer A";
  };

  localData = {
    vpnProfile = "vpn/profile.ovpn";
    bookmarks = "bookmarks/bookmarks.json";
    certificates = "certs";
  };
}
```

Product defaults can provide:

```nix
{
  icon = "...";
  colorFamily = "...";
}
```

Environment defaults can provide:

```nix
{
  icon = "...";
  accent = "...";
}
```

The resolved workspace configuration combines:

```text
common defaults
+ product defaults
+ environment defaults
+ workspace overrides
```

Sensitive values themselves are not part of the workspace definition.

The workspace definition only describes the expected local-data shape.

---

# Command Interface

All commands run from the repository root inside the Nix development shell.

The primary interface should not require users to invoke Tart directly for normal usage.

Provide repo-local commands with a consistent structure.

Preferred UX:

```bash
vm init PRODUCT ENVIRONMENT
vm import-vpn PRODUCT ENVIRONMENT SOURCE
vm import-bookmarks PRODUCT ENVIRONMENT SOURCE
vm import-cert PRODUCT ENVIRONMENT SOURCE
vm up PRODUCT ENVIRONMENT
vm down PRODUCT ENVIRONMENT
vm restart PRODUCT ENVIRONMENT
vm rebuild PRODUCT ENVIRONMENT
vm status PRODUCT ENVIRONMENT
vm list
```

Examples:

```bash
vm init consul customer-a
vm import-vpn consul customer-a ~/Downloads/client.ovpn
vm import-bookmarks consul customer-a ~/Downloads/bookmarks.json
vm up consul customer-a
vm down consul customer-a
vm rebuild consul customer-a
vm status consul customer-a
```

The command implementation may be a shell program, Go program, Rust program, Python program, or Nix app.

Prefer the smallest maintainable implementation.

Do not require:

```bash
./scripts/some/deep/path/vm ...
```

The dev shell should expose the command directly.

---

# Command Semantics

## `vm init PRODUCT ENVIRONMENT`

Creates the canonical local-only workspace data structure.

Must not overwrite existing sensitive files.

## `vm import-vpn PRODUCT ENVIRONMENT SOURCE`

Copies a VPN profile into the canonical local-only path with restrictive permissions.

Must not silently overwrite an existing profile.

## `vm import-bookmarks PRODUCT ENVIRONMENT SOURCE`

Copies a bookmark definition into the canonical local-only path with restrictive permissions.

Must not silently overwrite existing bookmarks.

## `vm import-cert PRODUCT ENVIRONMENT SOURCE`

Copies a certificate-related file into the canonical local-only certificate directory.

Must preserve restrictive permissions.

## `vm up PRODUCT ENVIRONMENT`

Must:

1. validate the workspace exists
2. derive `VM_NAME`
3. ensure required Tart VM artifacts exist
4. ensure the VM is configured for the expected workspace
5. start the VM
6. open/present the graphical guest
7. preserve existing persistent state

It may rebuild automatically if that can be done safely and predictably.

If automatic rebuild behavior becomes surprising, require explicit `vm rebuild`.

## `vm down PRODUCT ENVIRONMENT`

Must cleanly stop the VM.

Prefer graceful shutdown before forced termination.

## `vm restart PRODUCT ENVIRONMENT`

Equivalent to a clean stop followed by start.

## `vm rebuild PRODUCT ENVIRONMENT`

Must apply the latest declarative NixOS configuration while preserving persistent browser/user state.

The implementation must clearly distinguish:

```text
rebuild configuration
```

from:

```text
destroy/recreate persistent state
```

## `vm status PRODUCT ENVIRONMENT`

Should show useful non-sensitive information such as:

```text
󰛳 consul / 󰀄 customer-a
VM: consul-customer-a
State: running
VPN: connected
```

Do not print sensitive VPN endpoints or internal URLs by default.

## `vm list`

Should show all configured workspaces and their VM state.

Example:

```text
PRODUCT   ENVIRONMENT   VM NAME               STATE
consul    customer-a    consul-customer-a      running
consul    customer-b    consul-customer-b      stopped
vault     customer-a    vault-customer-a       running
```

Icons and colors may be used when output is interactive.

---

# Optional Environment Variable Interface

The command implementation may also support:

```bash
PRODUCT=consul
ENVIRONMENT=customer-a
vm up
```

but positional arguments should remain available.

If both are present, explicit positional arguments should either:

- take precedence, or
- produce a clear error on mismatch

Choose one behavior and document it.

Do not silently operate on an ambiguous workspace.

---

# Safety Against Wrong-Workspace Operations

This system exists partly to reduce accidental work against the wrong customer/environment.

The implementation should reinforce identity in multiple independent ways:

1. VM name
2. hostname
3. wallpaper
4. desktop accent
5. browser profile
6. terminal prompt
7. window title where practical

When destructive or high-impact helper commands are added later, they should have access to `PRODUCT` and `ENVIRONMENT`.

Do not rely on color alone.

---

# Base Image Strategy

Prefer a reusable graphical NixOS base image.

Conceptually:

```text
graphical NixOS base
        ↓
workspace VM
        +
persistent workspace disk/state
```

Do not rebuild a complete VM disk image for every routine Nix configuration change unless required by the chosen Tart/Nix integration.

The target workflow is:

```text
stable VM identity
+ persistent session state
+ declaratively rebuildable system configuration
```

---

# VM Creation

Creation should be deterministic from workspace identity.

Given:

```text
PRODUCT=consul
ENVIRONMENT=customer-a
```

the implementation must always derive:

```text
VM_NAME=consul-customer-a
```

Creation must not require a manually chosen Tart VM name.

If a VM with the expected name already exists, creation logic must not silently destroy it.

---

# VM Destruction

Destruction is explicitly separate from stopping.

If implemented, use a command such as:

```bash
vm destroy PRODUCT ENVIRONMENT
```

This command should make it obvious that persistent state will be lost.

Do not overload `vm down` or `vm rebuild` to delete persistent state.

A future implementation may require explicit confirmation for destruction.

---

# Logs

Logs must be organized by workspace identity.

Conceptually:

```text
state/
  ${PRODUCT}/
    ${ENVIRONMENT}/
      logs/
```

or an equivalent platform-specific state root.

Logs must avoid recording sensitive values where practical.

Do not intentionally log:

- complete VPN profiles
- private keys
- client certificate secrets
- authentication tokens
- decrypted secret contents

---

# State Directory

Any repository-managed or host-side state directory must use the canonical identity layout:

```text
${PRODUCT}/${ENVIRONMENT}
```

For example:

```text
.state/
  consul/
    customer-a/
    customer-b/
  vault/
    customer-a/
```

Do not flatten this to inconsistent names unless required by Tart itself.

When Tart requires the flattened name, use:

```text
${PRODUCT}-${ENVIRONMENT}
```

---

# Nix Development Shell

The repository development shell should provide everything needed for normal management.

At minimum, expose:

- `nix`
- the `vm` command
- `tart`
- any wallpaper/image generation dependencies
- formatting/linting tools used by the repo

Normal management should begin with entering the dev shell and then using the repo-local command interface.

The design assumes the caller is already inside that shell.

Do not make each lifecycle command invoke `nix develop` recursively.

---

# Flake Interface

The flake should expose useful machine-consumable outputs.

Possible outputs include:

```text
packages
apps
nixosConfigurations
checks
formatter
devShells
```

The exact shape is implementation-dependent.

The workspace registry should be discoverable from Nix rather than duplicated manually in multiple scripts.

Prefer a single resolved workspace data model consumed by both:

- NixOS configuration generation
- lifecycle tooling

Avoid maintaining independent workspace lists in shell scripts and Nix.

---

# Validation

Fail early on invalid workspace definitions.

Validate at least:

- `PRODUCT` exists
- `ENVIRONMENT` exists
- workspace combination exists
- identity fields resolve
- required local-data declarations resolve
- names are hostname-safe
- names are filesystem-safe
- no duplicate canonical VM name exists

Where possible, expose validation through:

```bash
nix flake check
```

---

# Initial Implementation Phases

## Phase 1: VM Proof of Concept

Implement one workspace.

Prove:

1. Tart boots a graphical NixOS guest.
2. The desktop is usable.
3. Browser state persists across reboot.
4. The VPN client can authenticate using the real SAML flow.
5. VPN routing and DNS stay inside the guest.
6. Internal browser resources work.
7. Host source sharing works if enabled.

Do not build the full multi-workspace abstraction before these are proven.

## Phase 2: Declarative Identity

Add:

- `PRODUCT`
- `ENVIRONMENT`
- canonical names
- icons
- palette
- wallpaper
- terminal identity
- browser identity

## Phase 3: Local-Only Sensitive Data Boundary

Add:

- XDG-style local workspace data root
- `vm init`
- `vm import-vpn`
- `vm import-bookmarks`
- `vm import-cert`
- runtime materialization into the guest
- VPN profile handling
- internal URL/bookmark handling
- certificate handling

Verify:

- sensitive values are never committed to Git
- sensitive values do not appear in the Nix store
- local workspace paths follow `PRODUCT/ENVIRONMENT`
- restrictive permissions are applied

## Phase 4: Multi-Workspace Lifecycle

Add:

```text
vm up
vm down
vm restart
vm rebuild
vm status
vm list
```

Prove multiple overlapping VPNs can be active simultaneously in different VMs.

## Phase 5: Refinement

Potential additions:

- VPN connection status in desktop panel
- VM status icons
- browser start page generated at runtime
- controlled host shares
- clipboard policy
- notifications
- cleanup commands
- secret rotation workflow
- state backup policy

---

# Acceptance Criteria

The initial system is successful when all of the following are true:

1. A workspace can be declared using `PRODUCT` and `ENVIRONMENT`.
2. Its Tart VM name is deterministically derived.
3. `vm up PRODUCT ENVIRONMENT` launches the graphical VM.
4. The VM has a clearly distinguishable visual identity.
5. Browser identity matches the VM identity.
6. Terminal identity matches the VM identity.
7. AWS Client VPN can complete the required interactive SAML flow.
8. The VPN route does not alter macOS host routing.
9. Two VMs with overlapping private CIDRs can remain connected simultaneously.
10. Browser/SAML state survives a normal VM restart.
11. NixOS configuration can be rebuilt without destroying browser state.
12. VPN profiles do not appear in plaintext in the Nix store.
13. Internal URLs do not appear in plaintext in the Nix store.
14. VPN profiles and internal bookmarks are never committed to Git, even encrypted.
15. `vm init PRODUCT ENVIRONMENT` creates the canonical local data structure.
16. `vm import-vpn PRODUCT ENVIRONMENT SOURCE` places the profile in the canonical location with restrictive permissions.
17. Local sensitive data uses `${XDG_DATA_HOME:-$HOME/.local/share}/vm-vpn/${PRODUCT}/${ENVIRONMENT}`.
18. Source code remains on the macOS host.
19. Normal management commands work from the repo root inside the dev shell.
20. Product and environment icons are stored declaratively in the repository.
21. Product/environment colors are stored declaratively in the repository.
22. Wallpaper, browser theme, terminal theme, and desktop theme consume the same resolved identity.
23. Browser visual identity is declarative while bookmarks/internal URLs remain local-only runtime data.

---

# Important Implementation Invariants

Codex should preserve these invariants while implementing the system:

```text
PRODUCT + ENVIRONMENT uniquely identifies a workspace.

VM_NAME = "${PRODUCT}-${ENVIRONMENT}"

workspace filesystem identity = "${PRODUCT}/${ENVIRONMENT}"

Nix configuration is declarative.

Browser/session state is persistent.

Sensitive connectivity information is local-only and runtime-injected.

Sensitive workspace values must never be committed to Git, even encrypted.

Plaintext sensitive values must not enter the Nix store.

Tart is the VM runtime, not the configuration source of truth.

The macOS host remains the development workstation.

The guest owns VPN routing, DNS, browser identity, and SAML state.

Visual identity must be redundant and obvious.

Visual identity data is Git-managed and non-sensitive.

Wallpaper, browser, terminal, desktop, and status output must consume one resolved identity model.

Sensitive browser content such as bookmarks/internal URLs must remain separate from browser visual identity.

Stopping/rebuilding a VM must not destroy persistent state.

Destroying persistent state must be an explicit separate operation.

All normal commands run from the repository root inside the Nix dev shell.
```

---

# Guidance for Codex

When implementing this design:

1. Start with the smallest working vertical slice.
2. Do not create abstractions before the Tart + graphical NixOS + SAML VPN flow is proven.
3. Keep sensitive values out of Git entirely.
4. Keep sensitive values out of the Nix store.
5. Prefer derived values over duplicated configuration.
6. Keep `PRODUCT` and `ENVIRONMENT` explicit throughout the data model.
7. Use the same resolved workspace model for Nix configuration and lifecycle tooling.
8. Keep Tart-specific code isolated so the higher-level workspace model does not depend heavily on Tart internals.
9. Preserve persistent browser/session state across rebuilds.
10. Make wrong-workspace mistakes visually difficult.
11. Avoid introducing host-global VPN routing.
12. Do not assume internal URLs are safe to place in generated Nix files.
13. Do not add interactive prompts to routine `up`, `down`, `status`, or `list` operations unless necessary.
14. Treat destructive state deletion separately and conservatively.
15. Add checks/tests where behavior can be validated without booting a VM.
16. Document any behavior that cannot be made declarative because it depends on interactive SAML or mutable browser state.
