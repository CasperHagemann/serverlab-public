# Progress

## Implemented

| Area                   | State                                                                                                                                                                                                                                                                                                                           |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Documentation          | README, ADR-0001 to ADR-0004, `docs/design/` 00-08, `inventory/`, `docs/control-node.md`                                                                                                                                                                                                                                        |
| Toolchain              | `scripts/control-node/check.sh` (fix and `--check` modes), pre-commit hook, bats suite (95 tests)                                                                                                                                                                                                                               |
| Proxmox-node scripting | `scripts/lib/` (log, guards, prompt, files, config, pve, net, disk), `scripts/remote-run.sh`, ADR-0003                                                                                                                                                                                                                          |
| Networking             | `10-network.sh` applied on `pve.kiwik.org`: `vmbr1` on `nic1`                                                                                                                                                                                                                                                                   |
| Storage                | `20-storage.sh` applied: `local-data` btrfs (`nvme0n1p4`, ~853 GiB), OS storages disabled, test VM booted                                                                                                                                                                                                                       |
| Post-install           | `05-proxmox-install.sh`: `TIMEZONE` (empty reverts via `/etc/timezone.orig`), NTP (chrony, `NTP_SERVERS`; empty reverts via `chrony.conf.orig`), APT repositories (`PVE_REPOSITORY`, `CEPH_REPOSITORY`; enterprise repos disabled; stock files in `/etc/apt/sources.list.orig/`; applied, re-run and revert tested on the node) |
| Full deployment        | `scripts/remote-run.sh <user@host> <stage>... \| all [-- <flags>]`: all stages in one `ssh -t` call (one login), config chosen on the node by hostname, stops at the first failing stage, `log::reboot_required` reminder in `/run/serverlab/reboot-required`; dry-run, apply and re-run checked on the node                    |
| Resource priority      | `25-resource-priority.sh`, ADR-0005 (see `docs/design/09-resource-management.md`)                                                                                                                                                                                                                                               |
| MCP servers            | `fetch`, `sequential-thinking` (see `.cline/mcp.json`)                                                                                                                                                                                                                                                                          |

## Planned

| Item                      | Reference                                                     |
| ------------------------- | ------------------------------------------------------------- |
| Post-install tasks        | `docs/design/02-proxmox-install.md` (updates, repos)          |
| Backups (PBS)             | `docs/design/06-backup-recovery.md`                           |
| Security and access       | `docs/design/05-security-access.md`                           |
| Monitoring                | `docs/design/07-monitoring.md`                                |
| Clustering / HA           | `docs/design/08-high-availability.md` (phase 2)               |
| Overview, hardware design | `docs/design/00-overview.md`, `01-hardware-firmware.md`       |
| CI                        | GitHub Actions running the same checks as a required PR check |

## Known issues

None.
