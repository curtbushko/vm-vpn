# Phase 1 Host Facts

Captured on 2026-08-27 before changing host routing or DNS.

| Fact | Value |
| --- | --- |
| Host architecture | `arm64` |
| macOS | `27.0` (`26A5353q`) |
| Nix | Determinate Nix `3.15.0`, Nix `2.33.0` |
| Nix host platform | `aarch64-darwin` |
| Extra local platform | `x86_64-darwin` |
| Configured builder | `ssh-ng://linux-builder` (not resolvable) |
| Tart on initial `PATH` | absent |
| Pinned Tart candidate | `2.36.0`, published 2026-08-25 |
| Tart archive SHA-256 | `c72a8ab8d78a6498a1e42688b1a1ec6c512ce46ca35a3a3be130c3de1440c7e8` |
| Shell test/lint tools | Bats, ShellCheck, and shfmt available |

## Selected Image Path

Use an ARM64 Linux bootstrap image under Tart to obtain a working
`aarch64-linux` Nix builder. Build a NixOS ARM64 installer ISO through that
builder, then install it into the persistent `demo-dev` Tart VM.

The development shell will pin and expose Tart rather than relying on the
initial host `PATH` or Homebrew.
