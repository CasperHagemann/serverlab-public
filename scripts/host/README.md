# Host scripts

Scripts for configuring the Proxmox host itself: post-install setup,
storage, networking, security, backup, monitoring.

Scripts are numbered for run order (`10-`, `20-`, …), with a number gap
left between them so a script can be inserted without renaming existing
ones. See [`../README.md`](../README.md) for the conventions all
scripts here must follow (`set -euo pipefail`, shellcheck-clean, idempotent,
no hardcoded environment values, phase structure).

## Scripts

| Script          | Purpose                                                        |
| --------------- | -------------------------------------------------------------- |
| `10-network.sh` | Host networking: creates the general VM network bridge `vmbr1` |
| `20-storage.sh` | Host storage: creates the `local-data` btrfs partition/storage |

Run these on the Proxmox host itself — see
[`../remote-run.sh`](../remote-run.sh) and
[`docs/dev-environment.md`](../../docs/dev-environment.md#running-scripts-on-the-remote-proxmox-host)
if you only have SSH access, not a clone of this repo on the host.
