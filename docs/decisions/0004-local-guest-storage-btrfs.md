# 0004. Local guest storage: btrfs

Status: Accepted

Date: 2026-09-29

## Context

The Proxmox node has a single NVMe. The OS occupies the first ~100 GB; the remaining
space is available for guest storage. One storage entry must hold all content
types (VM disks, container rootdirs, ISOs, templates, backups, snippets). The
Proxmox node is a single node with limited RAM.

## Decision

Create one btrfs partition in the free space and register it as the Proxmox
storage `local-data` for all content types. Disable the OS storages `local`
and `local-btrfs`. Details: [`docs/design/storage.md`](../design/storage.md).

Alternatives considered and rejected:

- **LVM-thin**: cannot hold file-based content (ISOs, templates, backups) in
  the same storage entry as VM disks and container rootdirs.
- **ZFS**:
  - RAM/ARC overhead.
  - The `zfspool` storage type holds only VM disks and container rootdirs.
    File-based content (ISOs, templates, backups, snippets) requires an
    additional `dir` storage on a separate dataset, i.e. two storage entries
    instead of one.
  - Rollback only to the most recent snapshot; rolling back to an older
    snapshot destroys all snapshots taken after it (`zfs rollback -r`).
    btrfs allows rollback to any snapshot without removing newer ones.

## Consequences

- Same filesystem as the OS; low RAM overhead; thin provisioning and
  copy-on-write snapshots/clones by default.
- One storage entry holds all content types.
- Guests can be rolled back to any snapshot; newer snapshots are kept.
- btrfs is a Proxmox technology preview.
- No `pvesr` replication. Phase 2 HA requires shared storage (e.g. NFS/Ceph)
  or a storage change.
- VM disks on btrfs must not use `cache=none`, to prevent silent filesystem
  corruption; use the default or `writeback`.
