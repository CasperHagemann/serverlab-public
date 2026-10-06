# Proxmox-node scripts

Scripts for configuring the Proxmox node itself: post-install setup,
storage, networking, security, backup, monitoring.

There is one script per design area, named after its design doc in
[`docs/design/`](../../docs/design/). The scripts are independent of each other
and need only a freshly installed Proxmox node. See
[`../README.md`](../README.md) for the conventions all scripts here must follow
(`set -euo pipefail`, shellcheck-clean, idempotent, no hardcoded environment
values, phase structure).

## Scripts

| Script                   | Purpose                                                                       |
| ------------------------ | ----------------------------------------------------------------------------- |
| `base-system.sh`         | Proxmox-node post-install: time zone, NTP (chrony) servers, APT repositories  |
| `networking.sh`          | Proxmox-node networking: creates the general VM network bridge `vmbr1`        |
| `storage.sh`             | Proxmox-node storage: creates the `local-data` btrfs partition/storage        |
| `resource-management.sh` | Proxmox-node resource priority: CPU, disk I/O and memory weights for the node |

Run these on the Proxmox node itself — see
[`../remote-run.sh`](../remote-run.sh) and
[`docs/control-node.md`](../../docs/control-node.md#running-scripts-on-the-remote-proxmox-node)
if you only have SSH access, not a clone of this repo on the Proxmox node.
