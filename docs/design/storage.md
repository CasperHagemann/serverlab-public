# Design: Storage

## Scope

Local vs shared storage, filesystem choice, pool layout.

## Configuration

### Guest storage

`LOCAL_DATA_STORAGE_ID` is the Proxmox storage ID of the guest storage, for example `local-data`. It is a btrfs filesystem on a new partition in the free space of the OS disk, mounted at `LOCAL_DATA_MOUNTPOINT` (for example `/mnt/local-data`). `LOCAL_DATA_STORAGE_PATH` is the subfolder the storage uses (for example `/mnt/local-data/pve-storage`) and `LOCAL_DATA_CONTENT` the content types it accepts (for example `images,rootdir,vztmpl,iso,backup,snippets`).

Fixed by the script, not by the node config:

| Setting              | Value                                                                                   |
| -------------------- | --------------------------------------------------------------------------------------- |
| `--is_mountpoint`    | `LOCAL_DATA_MOUNTPOINT`                                                                 |
| `/etc/fstab` options | `noatime,compress=zstd:1,nofail`                                                        |
| Provisioning         | Thin: sparse raw VM disks, subvolume container rootdirs, copy-on-write snapshots/clones |

### OS storages

`OS_STORAGES` is a space-separated list of Proxmox storages to disable, for example `local local-btrfs`. They are disabled with `pvesm set <storage> --disable 1`.

| Value of `OS_STORAGES` | Effect                      |
| ---------------------- | --------------------------- |
| One or more IDs        | Those storages are disabled |

### Disk and size

`LOCAL_DATA_MIN_GIB` is the minimum partition size; the script rejects a smaller free extent. `LOCAL_DATA_DISK` is optional and overrides OS-disk detection, for example `/dev/nvme0n1`.

## Constraints

- btrfs is a Proxmox technology preview.
- No `pvesr` replication on btrfs.
- VM disks on btrfs must not use `cache=none` (default or `writeback`).
- Proxmox refuses to write to the storage path when `LOCAL_DATA_MOUNTPOINT` is not mounted (`--is_mountpoint`).

## Implementation

Script: `scripts/proxmox-node/storage.sh` ([`scripts/README.md`](../../scripts/README.md)). Steps:

1. Detect the OS disk (`disk::os_disk`, or `LOCAL_DATA_DISK`), validate its geometry, find the largest free extent (1 MiB-aligned).
2. Create a partition in that extent with `sgdisk`; reject if smaller than `LOCAL_DATA_MIN_GIB`.
3. Load the partition (`partx -a --nr <n>`), format btrfs, add the `/etc/fstab` entry, run `systemctl daemon-reload`.
4. Mount at `LOCAL_DATA_MOUNTPOINT`, create `LOCAL_DATA_STORAGE_PATH`, register it with `pvesm add btrfs --is_mountpoint <mountpoint>`.
5. Disable `OS_STORAGES`.

Re-running is idempotent. If the guest storage is mounted and registered, only re-enabled `OS_STORAGES` entries are disabled. If nothing differs, the script reports "nothing to do".

On failure after the apply step starts, the script stops and prints manual undo steps (GPT backup restore, fstab backup restore); see [ADR-0003](../decisions/0003-proxmox-node-script-structure-and-conventions.md).

## Verification

| Check                                    | Expected result                                        |
| ---------------------------------------- | ------------------------------------------------------ |
| `findmnt <LOCAL_DATA_MOUNTPOINT>`        | Single mount; present after reboot                     |
| `pvesm status`                           | `LOCAL_DATA_STORAGE_ID` active; `OS_STORAGES` disabled |
| Test VM with ISO and disk on the storage | Creates and boots with a working console               |
| `storage.sh` re-run                      | Reports nothing to do                                  |

## Decision records

- [ADR-0004](../decisions/0004-local-guest-storage-btrfs.md): btrfs for local guest storage.

## Planned

> Not implemented.

None.
