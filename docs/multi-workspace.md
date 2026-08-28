# Multi-workspace Operation

`demo/dev` and synthetic `consul/lab` prove that identity, NixOS evaluation,
Tart names, local data, state, logs, source snapshots, and runtime
materialization are keyed by `PRODUCT/ENVIRONMENT`. Registry validation prevents
unknown or duplicate canonical names.

The flake evaluates both complete graphical NixOS configurations and a
ten-identity synthetic matrix. The fake Tart contract starts both workspace
names concurrently and proves their host/runtime inputs remain separate. This
does not prove real overlapping VPN routes or DNS; those checks remain in the
Phase 6 live acceptance list.

Each configured VM defaults to 6 virtual CPUs, 16 GiB RAM, an 80 GiB disk, and
a laptop-friendly 1440x900 initial display. Tart display refitting is enabled,
so the running guest follows the available window size instead of remaining at
that fallback resolution.
Two simultaneous VMs therefore request 12 CPUs, 32 GiB RAM, and 160 GiB of
provisioned disk. Operators should lower per-VM allocations before approaching
ten simultaneously running graphical VMs; the ten-workspace target concerns
configuration manageability, not running all ten at once.
