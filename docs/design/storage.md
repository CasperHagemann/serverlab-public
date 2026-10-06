# Design: Storage

## Scope

Local vs shared storage, filesystem choice, pool layout.

## Configuration

### Guest storage

`STORAGE_ID` is the Proxmox storage ID of the guest storage, for example `local-data`. It is a btrfs filesystem on a new partition in the free space of the OS disk, mounted at `STORAGE_MOUNTPOINT` (for example `/mnt/local-data`). `STORAGE_PATH` is the subfolder the storage uses (for example `/mnt/local-data/pve-storage`) and `STORAGE_CONTENT` the content types it accepts (for example `images,rootdir,vztmpl,iso,backup,snippets`).

Fixed by the script, not by the node config:

| Setting              | Value                                                                                   |
| -------------------- | --------------------------------------------------------------------------------------- |
| `--is_mountpoint`    | `STORAGE_MOUNTPOINT`                                                                    |
| `/etc/fstab` options | `noatime,compress=zstd:1,nofail`                                                        |
| Provisioning         | Thin: sparse raw VM disks, subvolume container rootdirs, copy-on-write snapshots/clones |

### OS storages

`STORAGE_OS_DISABLE` is a space-separated list of Proxmox storages to disable, for example `local local-btrfs`. They are disabled with `pvesm set <storage> --disable 1`.

| Value of `STORAGE_OS_DISABLE` | Effect                      |
| ----------------------------- | --------------------------- |
| One or more IDs               | Those storages are disabled |

### Disk and size

`STORAGE_MIN_GIB` is the minimum partition size; the script rejects a smaller free extent. `STORAGE_DISK` is optional and overrides OS-disk detection, for example `/dev/nvme0n1`.

## Constraints

- btrfs is a Proxmox technology preview.
- No `pvesr` replication on btrfs.
- VM disks on btrfs must not use `cache=none` (default or `writeback`).
- Proxmox refuses to write to the storage path when `STORAGE_MOUNTPOINT` is not mounted (`--is_mountpoint`).

## Implementation

Script: `scripts/proxmox-node/storage.sh` ([`scripts/README.md`](../../scripts/README.md)). Steps:

1. Detect the OS disk (`disk::os_disk`, or `STORAGE_DISK`), validate its geometry, find the largest free extent (1 MiB-aligned).
2. Create a partition in that extent with `sgdisk`; reject if smaller than `STORAGE_MIN_GIB`.
3. Load the partition (`partx -a --nr <n>`), format btrfs, add the `/etc/fstab` entry, run `systemctl daemon-reload`.
4. Mount at `STORAGE_MOUNTPOINT`, create `STORAGE_PATH`, register it with `pvesm add btrfs --is_mountpoint <mountpoint>`.
5. Disable `STORAGE_OS_DISABLE`.

Re-running is idempotent. If the guest storage is mounted and registered, only re-enabled `STORAGE_OS_DISABLE` entries are disabled. If nothing differs, the script reports "nothing to do".

The manual undo steps printed on failure are the GPT backup restore and the fstab backup restore.

## Verification

| Check                                    | Expected result                                    |
| ---------------------------------------- | -------------------------------------------------- |
| `findmnt <STORAGE_MOUNTPOINT>`           | Single mount; present after reboot                 |
| `pvesm status`                           | `STORAGE_ID` active; `STORAGE_OS_DISABLE` disabled |
| Test VM with ISO and disk on the storage | Creates and boots with a working console           |
| `storage.sh` re-run                      | Reports nothing to do                              |

## Decision records

- [ADR-0012](../decisions/0012-local-guest-storage-btrfs.md): btrfs for local guest storage.

## Planned

None.
