# Progress

## Implemented

| Area                   | State                                                                                                      |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| Documentation          | README, ADR-0001 to ADR-0004, `docs/design/` 00-08, `inventory/`, `docs/control-node.md`                   |
| Toolchain              | `scripts/control-node/check.sh` (fix and `--check` modes), pre-commit hook, bats suite (51 tests)          |
| Proxmox-node scripting | `scripts/lib/` (log, guards, prompt, files, config, pve, net, disk), `scripts/remote-run.sh`, ADR-0003     |
| Networking             | `10-network.sh` applied on `pve.kiwik.org`: `vmbr1` on `nic1`                                              |
| Storage                | `20-storage.sh` applied: `local-data` btrfs (`nvme0n1p4`, ~853 GiB), OS storages disabled, test VM booted  |
| NTP                    | `05-proxmox-install.sh` (chrony, `NTP_SERVERS` array; empty reverts to OS defaults via `chrony.conf.orig`) |
| MCP servers            | `fetch`, `sequential-thinking` (see `.cline/mcp.json`)                                                     |

## Planned

| Item                      | Reference                                                      |
| ------------------------- | -------------------------------------------------------------- |
| Post-install tasks        | `docs/design/02-proxmox-install.md` (timezone, updates, repos) |
| Fair I/O sharing          | `docs/design/04-storage.md` (cgroup v2, BFQ)                   |
| Backups (PBS)             | `docs/design/04-storage.md`, `06-backup-recovery.md`           |
| Security and access       | `docs/design/05-security-access.md`                            |
| Monitoring                | `docs/design/07-monitoring.md`                                 |
| Clustering / HA           | `docs/design/08-high-availability.md` (phase 2)                |
| Overview, hardware design | `docs/design/00-overview.md`, `01-hardware-firmware.md`        |
| CI                        | GitHub Actions running the same checks as a required PR check  |

## Known issues

None.
