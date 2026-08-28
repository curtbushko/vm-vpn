# Hardening and Operations

## Interaction and sharing policy

Lifecycle starts disable host clipboard and audio. Drag/drop and downloads do
not receive an implicit writable host share. A read-only snapshot of the
committed repository is always mounted at `/mnt/shared/repo`.

Users can configure additional allowlisted directories with `vm share-add`.
Settings are stored locally at
`${XDG_CONFIG_HOME:-$HOME/.config}/vm-vpn/PRODUCT/ENVIRONMENT/shares.json` with
mode `0600`, never in Git or the Nix store. Names and absolute paths are
validated, collisions are rejected, and read-only is the default. The
`--read-write` option is an explicit trust decision. Tart exposes the named
directories through one virtiofs device; lifecycle keeps its backing mount
root-only and bind-mounts each setting at `/mnt/shared/NAME` with its configured
access mode. `vm share-remove` removes only the setting, not host data.
Sensitive XDG data is streamed to guest tmpfs and is never shared persistently.
Firefox downloads and browser/session state remain inside the encrypted-at-rest
policy boundary chosen for the Tart disk; notifications stay guest-local.

## Diagnostics and cleanup

`vm diagnose PRODUCT ENVIRONMENT` reports canonical identity, profile presence
and mode, Tart state, and runtime-material state. It never reads endpoints,
URLs, certificates, credentials, or profile contents.

`vm cleanup PRODUCT ENVIRONMENT` moves source snapshots and operational logs to
the workspace state directory's `.trash/` subtree. It does not delete local
data, browser state, or a Tart VM. There is no VM-destruction command.

## Disk protection and recovery

Treat the Tart disk and every backup as sensitive because Firefox sessions,
downloads, and imported certificate state persist. Stop the VM before using
`tart clone` or `tart export`; store the result only on encrypted storage with
restricted access. Test restores under a new temporary Tart name before relying
on a backup. Rotate the source VPN profile/certificates by moving the previous
local files to the local `.trash/`, importing replacements, and restarting.
Never commit or place backups beneath this repository.

Interrupted installs retain the VM and installer log. Re-run `vm up`; the guest
installer has a `--resume` mode for a mounted partial installation. Failed
runtime material disappears at shutdown and is recreated on the next start.

## Live acceptance deferred

Synthetic fixtures and fake Tart contracts pass, but they do not establish the
following external facts:

1. AWS browser SAML completes with the selected test endpoint.
2. `openaws-vpn-client` connects with the organization's current profile.
3. VPN-provided DNS and routes work inside each guest.
4. An approved internal hostname/URL is reachable with required certificates.
5. macOS DNS/routes remain byte-for-byte unchanged during one or two connected
   VPN sessions, including overlapping private CIDRs.

When real data is available, capture macOS `scutil --dns` and `netstat -rn`
before startup, connect interactively in each VM, check guest `resolvectl`,
`ip route`, and the approved resource, then compare host snapshots after
disconnect. Store evidence outside Git and redact endpoints, routes, hostnames,
URLs, account identifiers, and certificate details. Until then these five items
are accepted limitations, not passing tests.
