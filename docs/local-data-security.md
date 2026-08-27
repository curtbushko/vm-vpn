# Local Data Security Boundary

Workspace configuration and visual identity are public Git inputs. VPN
profiles, bookmarks, certificates, private keys, browser state, generated VPN
configuration, endpoints, and internal URLs are sensitive runtime data.

Host data lives beneath
`${XDG_DATA_HOME:-$HOME/.local/share}/vm-vpn/PRODUCT/ENVIRONMENT` with `0700`
directories and `0600` files. Imports copy without deleting their source and
refuse collisions. Nothing beneath that root is a flake input.

`vm materialize` streams a tar archive over Tart guest-agent stdin. Contents do
not appear in process arguments or routine logs. The guest extracts into
tmpfs-backed `/run/vpn-workspace`, creates the openaws client selection there,
generates an escaped runtime start page, and imports runtime CA certificates
into an existing Firefox NSS profile. The directory disappears at shutdown.
The openaws package redirects its generated data/configuration into the same
runtime root and removes upstream endpoint logging.

Persistent browser state is sensitive even though it is not reproducible. VM
disk backups must therefore receive the same protection as the source profile.
Tart shares are read-only and allowlisted; the sensitive host data directory is
never mounted as a persistent share.

Routine diagnostics may report only workspace identity, VM state, VPN state,
file presence, modes, and component versions. They must not read or print file
contents, endpoints, URLs, certificate subjects, filenames, or credentials.
Synthetic canaries are generated during tests and checked against command logs;
tracked-source and closure scans reject common private-key and AWS key forms.

Real SAML approval and connected DNS/route tests remain Phase 6 manual
acceptance work. Synthetic fixtures validate transport and redaction, not
external authentication or network reachability.
