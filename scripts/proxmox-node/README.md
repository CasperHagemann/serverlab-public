# Proxmox-node scripts

Scripts for configuring the Proxmox node itself. There is one script per design
area, named after its design doc in [`docs/design/`](../../docs/design/). The
scripts are independent of each other and need only a freshly installed Proxmox
node. The conventions they follow are in [`../README.md`](../README.md).

## Scripts

| Script                   | Purpose                                                   |
| ------------------------ | --------------------------------------------------------- |
| `base-system.sh`         | Time zone, NTP (chrony) servers, APT repositories         |
| `networking.sh`          | The VLAN-aware VM trunk bridge                            |
| `storage.sh`             | The btrfs guest storage                                   |
| `resource-management.sh` | CPU, disk I/O and memory weights that prioritise the node |

Run these on the Proxmox node itself — see
[`../remote-run.sh`](../remote-run.sh) and
[`docs/control-node.md`](../../docs/control-node.md#running-scripts-on-the-remote-proxmox-node)
if you only have SSH access, not a clone of this repo on the Proxmox node.
