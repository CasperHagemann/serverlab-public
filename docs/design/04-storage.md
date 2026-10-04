# Design: Storage

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#4-storage-architecture) (unvetted).

## Scope

Local vs shared storage, filesystem choice, pool layout.

## Configuration

### Disk split (`pve.kiwik.org`)

| Partition        | Size     | Filesystem | Use                          |
| ---------------- | -------- | ---------- | ---------------------------- |
| `nvme0n1p1`-`p3` | ~100 GB  | btrfs      | Proxmox OS                   |
| `nvme0n1p4`      | ~853 GiB | btrfs      | Guest storage (`local-data`) |

### Proxmox storages

| Storage       | State    | Path                          | Content types                               |
| ------------- | -------- | ----------------------------- | ------------------------------------------- |
| `local-data`  | Active   | `/mnt/local-data/pve-storage` | `images,rootdir,vztmpl,iso,backup,snippets` |
| `local`       | Disabled | -                             | -                                           |
| `local-btrfs` | Disabled | -                             | -                                           |

| Setting                 | Value                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------- |
| Mountpoint              | `/mnt/local-data`                                                                       |
| Storage path            | Subfolder `pve-storage` of the mountpoint                                               |
| `--is_mountpoint`       | `/mnt/local-data`                                                                       |
| `/etc/fstab` options    | `noatime,compress=zstd:1,nofail`                                                        |
| OS storages             | Disabled with `pvesm set <storage> --disable 1`                                         |
| Provisioning            | Thin: sparse raw VM disks, subvolume container rootdirs, copy-on-write snapshots/clones |
| Local backups (`dump/`) | On `local-data`; not protected against loss of that disk                                |

## Constraints

- btrfs is a Proxmox technology preview.
- No `pvesr` replication on btrfs.
- VM disks on btrfs must not use `cache=none` (default or `writeback`).
- Proxmox refuses to write to the storage path when `/mnt/local-data` is not mounted (`--is_mountpoint`).

## Implementation

Script: `scripts/proxmox-node/20-storage.sh` ([`scripts/README.md`](../../scripts/README.md)). Steps:

1. Detect the OS disk (`disk::os_disk`, or `LOCAL_DATA_DISK`), validate its geometry, find the largest free extent (1 MiB-aligned).
2. Create a partition in that extent with `sgdisk`; reject if smaller than `LOCAL_DATA_MIN_GIB`.
3. Load the partition (`partx -a --nr <n>`), format btrfs, add the `/etc/fstab` entry, run `systemctl daemon-reload`.
4. Mount at `LOCAL_DATA_MOUNTPOINT`, create `LOCAL_DATA_STORAGE_PATH`, register it with `pvesm add btrfs --is_mountpoint <mountpoint>`.
5. Disable `OS_STORAGES`.

Re-running is idempotent. If `local-data` is mounted and registered, only re-enabled `OS_STORAGES` entries are disabled. If nothing differs, the script reports "nothing to do".

On failure after the apply step starts, the script stops and prints manual undo steps (GPT backup restore, fstab backup restore); see [ADR-0003](../decisions/0003-proxmox-node-script-structure-and-conventions.md).

Config: `config/proxmox-nodes/<hostname>.env` ([`config/README.md`](../../config/README.md)).

| Key                       | Purpose                             |
| ------------------------- | ----------------------------------- |
| `LOCAL_DATA_STORAGE_ID`   | Proxmox storage ID                  |
| `LOCAL_DATA_MOUNTPOINT`   | Mountpoint                          |
| `LOCAL_DATA_STORAGE_PATH` | Proxmox storage path                |
| `LOCAL_DATA_CONTENT`      | Content types                       |
| `LOCAL_DATA_MIN_GIB`      | Minimum partition size              |
| `OS_STORAGES`             | Storages to disable                 |
| `LOCAL_DATA_DISK`         | Optional OS-disk detection override |

## Verification

| Check                                     | Expected result                                      |
| ----------------------------------------- | ---------------------------------------------------- |
| `findmnt /mnt/local-data`                 | Single mount; present after reboot                   |
| `pvesm status`                            | `local-data` active; `local`, `local-btrfs` disabled |
| Test VM with ISO and disk on `local-data` | Creates and boots with a working console             |
| `20-storage.sh` re-run                    | Reports nothing to do                                |

## Decision records

- [ADR-0004](../decisions/0004-local-guest-storage-btrfs.md): btrfs for local guest storage.

---

## Planned

> Not implemented.

| Item             | Description                                                                                                                                                                                                                                                                                                     | Depends on                       |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| Fair I/O sharing | cgroup v2 `IOWeight` via `systemctl set-property`: `system.slice` 1000, `qemu.slice`/`lxc` 100, guest scopes at default 100. Requires the BFQ I/O scheduler (persisted via udev rule). Optional `io.max` cap on `qemu.slice`. Backup/restore/migration limited via `bwlimit` in `datacenter.cfg`/`vzdump.conf`. | Evaluation on real disk hardware |
