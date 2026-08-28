# Demo host share

This tracked directory demonstrates a read-only host share. After running
`vm seed demo dev`, it is available inside the guest at
`/mnt/shared/examples`.

The writable example is created outside Git at
`~/.local/share/vm-vpn/demo/dev/output` and mounted at `/mnt/shared/output`.
