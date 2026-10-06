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

All keys must be set. An empty value reverts that setting.

### CPU and I/O weights

`HOST_CPU_WEIGHT` is the `CPUWeight` and `HOST_IO_WEIGHT` the `IOWeight` of `system.slice` and `user.slice`, for example `1000` and `10000` (default 100). BFQ scales the I/O weight to 1-1000, so `10000` gives BFQ weight `1000`.

| Value of the weight keys | Effect                              |
| ------------------------ | ----------------------------------- |
| 1-10000                  | Sets the weight of both slices      |
| Empty `""`               | Reverts to the default weight (100) |
| Unset                    | The script stops with an error      |

### Memory protection

`HOST_MEMORY_LOW` is the memory of `system.slice` protected from reclaim, for example `4G`. It is protection under memory pressure, not a reservation.

| Value of `HOST_MEMORY_LOW` | Effect                                   |
| -------------------------- | ---------------------------------------- |
| A size (`4G`, `512M`)      | Sets `MemoryLow` of `system.slice`       |
| Empty `""`                 | Reverts to `MemoryLow` 0 (no protection) |
| Unset                      | The script stops with an error           |

### I/O scheduler

`IO_SCHEDULER` is the scheduler of the OS disk (`LOCAL_DATA_DISK` or auto-detected), for example `bfq`. BFQ is required for I/O weights.

| Value of `IO_SCHEDULER` | Effect                                                              |
| ----------------------- | ------------------------------------------------------------------- |
| A scheduler name        | Set on the OS disk by a udev rule; other devices keep their default |
| Empty `""`              | Restores the scheduler saved in `/etc/io-scheduler.orig`            |
| Unset                   | The script stops with an error                                      |

### Files written

Always the same on every node:

| Item            | Path                                                                  |
| --------------- | --------------------------------------------------------------------- |
| Drop-ins        | `/etc/systemd/system/{system,user}.slice.d/50-resource-priority.conf` |
| Udev rule       | `/etc/udev/rules.d/60-io-scheduler.rules`                             |
| Saved scheduler | `/etc/io-scheduler.orig`                                              |
| Boot unit       | `serverlab-resource-priority.service`, enabled                        |

## Implementation

Script: `scripts/proxmox-node/resource-management.sh`
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

| Check                                                                             | Expected result                                                                                       |
| --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `cat /sys/fs/cgroup/system.slice/{cpu.weight,io.bfq.weight,io.weight,memory.low}` | `<HOST_CPU_WEIGHT>`, `default <BFQ weight>`, `default <HOST_IO_WEIGHT>`, `<HOST_MEMORY_LOW>` in bytes |
| `cat /sys/fs/cgroup/user.slice/{cpu.weight,io.bfq.weight}`                        | `<HOST_CPU_WEIGHT>`, `default <BFQ weight>`                                                           |
| `grep -H . /sys/block/*/queue/scheduler`                                          | The OS disk shows `[<IO_SCHEDULER>]`                                                                  |
| `systemctl status serverlab-resource-priority.service`                            | enabled, `active (exited)`, all `ExecStart` 0                                                         |
| `ls /run/systemd/system.control/`                                                 | No `system.slice.d` or `user.slice.d`                                                                 |
| `resource-management.sh --dry-run` after a reboot                                 | Reports nothing to do                                                                                 |

Repair test: after `systemctl set-property --runtime system.slice
CPUWeight=200`, `--dry-run` shows `cpu.weight 200 -> <HOST_CPU_WEIGHT>`, `--yes` repairs
it, `/run/systemd/system.control/` is left empty and a further `--dry-run`
reports nothing to do.

Revert test: with the four config keys empty, `--yes` removes the two
drop-ins, the unit and the udev rule, sets the scheduler of the OS disk back
to its previous scheduler (from `/etc/io-scheduler.orig`) and the values back to `cpu.weight`
100, `io.bfq.weight` and `io.weight` `default 100`, `memory.low` 0. The unit
is `not-found`, no runtime drop-ins are left and a further `--dry-run`
reports nothing to do. Restoring the keys and running `--yes` applies all
settings again. `/etc/io-scheduler.orig` and the `.bak.<timestamp>` backups
of the removed files are kept.

## Decision records

- [ADR-0005](../decisions/0005-node-resource-priority-and-fair-sharing.md):
  node priority by weights, not limits.

## Planned

> Not implemented.

None.
