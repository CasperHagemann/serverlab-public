# Progress

## Implemented

| Area                   | State                                                                                                                                                                                                                                                                                                                                        |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Documentation          | README, ADR-0001 to ADR-0013, `docs/design/`, `inventory/`, `docs/control-node.md`                                                                                                                                                                                                                                                           |
| Toolchain              | `scripts/control-node/check.sh` (fix and `--check` modes), pre-commit hook, bats suite (95 tests)                                                                                                                                                                                                                                            |
| Proxmox-node scripting | `scripts/lib/` (log, guards, prompt, files, config, pve, net, disk), `scripts/remote-run.sh`, ADR-0005 to ADR-0010                                                                                                                                                                                                                           |
| Networking             | `networking.sh` applied on `pve.kiwik.org`: `vmbr1` on `nic1`                                                                                                                                                                                                                                                                                |
| Storage                | `storage.sh` applied: `local-data` btrfs (`nvme0n1p4`, ~853 GiB), OS storages disabled, test VM booted                                                                                                                                                                                                                                       |
| Post-install           | `base-system.sh`: `BASE_TIMEZONE` (empty reverts via `/etc/timezone.orig`), NTP (chrony, `BASE_NTP_SERVERS`; empty reverts via `chrony.conf.orig`), APT repositories (`BASE_PVE_REPOSITORY`, `BASE_CEPH_REPOSITORY`; enterprise repos disabled; stock files in `/etc/apt/sources.list.orig/`; applied, re-run and revert tested on the node) |
| Full deployment        | `scripts/remote-run.sh <user@host> <stage>... \| all [-- <flags>]`: all stages in one `ssh -t` call (one login), config chosen on the node by hostname, stops at the first failing stage, `log::reboot_required` reminder in `/run/serverlab/reboot-required`; dry-run, apply and re-run checked on the node                                 |
| Resource priority      | `resource-management.sh`, ADR-0013 (see `docs/design/resource-management.md`)                                                                                                                                                                                                                                                                |
| MCP servers            | `fetch`, `sequential-thinking` (see `.cline/mcp.json`)                                                                                                                                                                                                                                                                                       |

## Planned

| Item                | Reference                                                     |
| ------------------- | ------------------------------------------------------------- |
| Post-install tasks  | `docs/design/base-system.md` (updates, repos)                 |
| Backups (PBS)       | `docs/design/backup-recovery.md`                              |
| Security and access | `docs/design/security-access.md`                              |
| Monitoring          | `docs/design/monitoring.md`                                   |
| Clustering / HA     | `docs/design/clustering.md` (phase 2)                         |
| CI                  | GitHub Actions running the same checks as a required PR check |

## Known issues

None.
