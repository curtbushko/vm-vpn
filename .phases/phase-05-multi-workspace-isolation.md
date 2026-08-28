# Phase 5: Multi-Workspace Isolation

## Objective

Generalize only after `demo/dev` is stable, then prove approximately ten configurations remain manageable and at least two overlapping VPN workspaces can run concurrently.

## Tasks

- [x] Select a second non-sensitive product/environment identity and use separate synthetic local-only VPN data without committing it.
- [x] Write failing registry/evaluation tests for multiple products, environments, workspace combinations, and canonical-name uniqueness.
- [x] Generalize workspace discovery and NixOS configuration generation without changing the public `PRODUCT ENVIRONMENT` ordering.
- [x] Add the second product, environment, and workspace declarations with visibly distinct icon, text, and palette.
- [x] Prove `vm list`, status, init, imports, build, and lifecycle operations work independently for both workspaces.
- [x] Run both fake Tart backends concurrently and prove names/data remain isolated; defer overlapping real VPN CIDRs to Phase 6.
- [x] Prove configuration and runtime boundaries keep DNS guest-local; defer connected macOS DNS/route snapshots to Phase 6.
- [x] Verify persistent disks, runtime material, shares, state, and logs cannot cross workspace boundaries.
- [x] Evaluate/build a generated matrix of roughly ten non-sensitive workspace definitions to detect scaling and naming problems without requiring ten live VPN sessions.
- [x] Document CPU, memory, disk, and operational limits observed with simultaneous graphical VMs.
- [x] Run all checks and update the Implementation Record with evidence and the next task.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` synchronized.

### 2026-08-27

- All 11 tasks complete with `consul/lab` as the visibly distinct synthetic
  second workspace. Both full NixOS configurations and a ten-identity matrix
  evaluate successfully.
- Fake concurrent lifecycle tests prove independent Tart names, XDG paths,
  runtime streams, state, logs, and read-only shares. Real overlapping VPN
  CIDR/DNS behavior remains a Phase 6 live acceptance item.
