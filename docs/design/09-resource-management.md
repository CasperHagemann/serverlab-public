# Design: Resource Management

> Decision: [ADR-0005](../decisions/0005-node-resource-priority-and-fair-sharing.md).

## Scope

Priority of the Proxmox node's own processes over guests for CPU, disk I/O
and memory, using cgroup v2 weights. Weights only, no limits. Not covered:
network, backups, migration.

## Constraints

- BFQ is required for disk I/O weights. The OS disk defaults to `none`.
- `IOWeight=` (1-10000) is scaled to BFQ's 1-1000: 1000 gives 181, 10000
  gives 1000. `CPUWeight=` is not scaled.
- `qemu.slice` passes only `cpu memory pids` to its children: VMs have no
  per-VM `io.bfq.weight`. Node/guest priority works at the top level
  (`system.slice` and `user.slice` against `qemu.slice`).
- systemd does not write a changed drop-in value to a running slice, and
  removing a drop-in leaves the kernel value unchanged. The script writes
  the values (or the defaults, `100` and `MemoryLow` 0, for empty
  settings) to the running slices with `systemctl set-property --runtime`.
- `system.slice` is created at about 1.6 s of boot, before the `bfq` module
  is registered (about 1.9 s; it is not in the initramfs). systemd therefore
  writes no `io.bfq.weight` to it, and it stays at 100 after a reboot.
  `user.slice` is created at first login and gets the weight. A boot unit
  writes the values after udev has set the scheduler.

## Configuration

### Live on `pve.kiwik.org`

| Item                         | Value                                                                 |
| ---------------------------- | --------------------------------------------------------------------- |
| `system.slice`, `user.slice` | `CPUWeight=1000`, `IOWeight=10000` (BFQ weight 1000)                  |
| `system.slice`               | `MemoryLow=4G`                                                        |
| OS disk (`nvme0n1`)          | I/O scheduler `bfq` (udev rule); other devices `none`                 |
| Drop-ins                     | `/etc/systemd/system/{system,user}.slice.d/50-resource-priority.conf` |
| Udev rule                    | `/etc/udev/rules.d/60-io-scheduler.rules`                             |
| Saved scheduler              | `/etc/io-scheduler.orig`                                              |
| Boot unit                    | `serverlab-resource-priority.service`, enabled                        |

## Config keys

Node config `config/proxmox-nodes/<hostname>.env`. All keys must be set; an
empty value reverts that setting.

| Key               | Value   | Meaning                                              |
| ----------------- | ------- | ---------------------------------------------------- |
| `HOST_CPU_WEIGHT` | `1000`  | `CPUWeight` of `system.slice` and `user.slice`       |
| `HOST_IO_WEIGHT`  | `10000` | `IOWeight` of `system.slice` and `user.slice`        |
| `HOST_MEMORY_LOW` | `4G`    | `MemoryLow` of `system.slice`                        |
| `IO_SCHEDULER`    | `bfq`   | Scheduler of the OS disk (`LOCAL_DATA_DISK` or auto) |

## Implementation

Script: `scripts/proxmox-node/25-resource-priority.sh`
([`scripts/README.md`](../../scripts/README.md)). Steps:

- Writes `/etc/systemd/system/system.slice.d/50-resource-priority.conf` and
  the same under `user.slice.d/` (`MemoryLow` only in `system.slice`).
- Writes `/etc/udev/rules.d/60-io-scheduler.rules` for the OS disk, and
  saves the previous scheduler in `/etc/io-scheduler.orig`.
- Writes `/etc/systemd/system/serverlab-resource-priority.service`, a
  oneshot unit run after `systemd-udev-settle.service` that applies the
  values to the running `system.slice` and `user.slice` at every boot, and
  enables it. A revert disables and removes it.
- Applies without a reboot: sets the scheduler, runs `systemctl
daemon-reload`, then writes the values to the running slices.
- Compares the live `cpu.weight`, `io.bfq.weight` and `memory.low` with the
  targets in the plan, so a missed or changed value is repaired on re-run.
  A missing `user.slice` file is skipped (the slice exists after the first
  login). A missing `io.bfq.weight` of `system.slice` counts as a change
  when `bfq` is the active scheduler; other missing `system.slice` files
  stop the script.
- Verifies the same values, the unit state and the active scheduler.
- Idempotent; `--dry-run` and `--yes`; no automatic rollback.

## Verification

| Check                                                                             | Expected result                                       |
| --------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `cat /sys/fs/cgroup/system.slice/{cpu.weight,io.bfq.weight,io.weight,memory.low}` | `1000`, `default 1000`, `default 10000`, `4294967296` |
| `cat /sys/fs/cgroup/user.slice/{cpu.weight,io.bfq.weight}`                        | `1000`, `default 1000`                                |
| `grep -H . /sys/block/*/queue/scheduler`                                          | `nvme0n1` is `[bfq]`                                  |
| `systemctl status serverlab-resource-priority.service`                            | enabled, `active (exited)`, all `ExecStart` 0         |
| `ls /run/systemd/system.control/`                                                 | No `system.slice.d` or `user.slice.d`                 |
| `25-resource-priority.sh --dry-run` after a reboot                                | Reports nothing to do                                 |

Repair test: after `systemctl set-property --runtime system.slice
CPUWeight=200`, `--dry-run` shows `cpu.weight 200 -> 1000`, `--yes` repairs
it, `/run/systemd/system.control/` is left empty and a further `--dry-run`
reports nothing to do.

Checked on `pve.kiwik.org` after a reboot. The revert has not been tested
on the node.

Fairness between several busy guests has not been measured.

## Decision records

- [ADR-0005](../decisions/0005-node-resource-priority-and-fair-sharing.md):
  node priority by weights, not limits.

## Planned

> Not implemented.

None.
