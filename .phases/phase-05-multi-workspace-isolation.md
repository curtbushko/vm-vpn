# Phase 5: Multi-Workspace Isolation

## Objective

Generalize only after `vault/dev` is stable, then prove approximately ten configurations remain manageable and at least two overlapping VPN workspaces can run concurrently.

## Tasks

- [ ] Select a second non-sensitive product/environment identity and obtain separate local-only test VPN data without committing it.
- [ ] Write failing registry/evaluation tests for multiple products, environments, workspace combinations, and canonical-name uniqueness.
- [ ] Generalize workspace discovery and NixOS configuration generation without changing the public `PRODUCT ENVIRONMENT` ordering.
- [ ] Add the second product, environment, and workspace declarations with visibly distinct icon, text, and palette.
- [ ] Prove `vm list`, status, init, imports, build, and lifecycle operations work independently for both workspaces.
- [ ] Run both Tart VMs concurrently and prove identical/overlapping private CIDRs do not conflict.
- [ ] Prove both VPN DNS contexts remain guest-local and the macOS routing/DNS state stays unchanged.
- [ ] Verify persistent disks, runtime material, shares, state, and logs cannot cross workspace boundaries.
- [ ] Evaluate/build a generated matrix of roughly ten non-sensitive workspace definitions to detect scaling and naming problems without requiring ten live VPN sessions.
- [ ] Document CPU, memory, disk, and operational limits observed with simultaneous graphical VMs.
- [ ] Run all checks and update the Implementation Record with evidence and the next task.

## Implementation Record

Append dated restart notes here. Keep `.phases/index.yaml` synchronized.
