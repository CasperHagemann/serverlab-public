# 0013. Node resource priority and fair sharing

Status: Accepted

Date: 2026-10-04

## Context

The Proxmox node runs its own services (web UI, cluster and storage
daemons, SSH sessions) on the same CPU, disk and memory as the guests. A
busy guest must not make the node unresponsive or starve its management
tasks. Guests should also share what is left fairly.

Scope: a single node, CPU, disk I/O and memory. Network, backups and
migration traffic are not covered.

Options:

- **Limits** (`io.max`, `cpulimit`, `bwlimit`): cap a consumer even when the
  resource is idle.
- **Weights** (`CPUWeight`, `IOWeight`, `MemoryLow`): only matter under
  contention; idle capacity stays available to guests.

Disk I/O weights need the BFQ I/O scheduler. The node's NVMe defaults to
`none`, and the `bfq` module is available. systemd scales `IOWeight=`
(1-10000) to the BFQ range 1-1000: `IOWeight=1000` gives BFQ weight 181 and
`IOWeight=10000` gives 1000. `CPUWeight=` is not scaled.

Measured on the node with one Ubuntu VM on `local-data` running `fio`, and
`dd` with `dsync` on the node as the foreground task (2.18 s without load):

| Run                                        | `dd` under load    | VM IOPS      |
| ------------------------------------------ | ------------------ | ------------ |
| A: `none`                                  | about 5.4 s        | 189k         |
| B: `bfq`                                   | about 3.5 s        | 88k (-53 %)  |
| C: `bfq` + `IOWeight=10000` on node slices | 3.24 / 8.97 / 3.09 | 134k (-29 %) |

The web UI felt the same in all runs.

## Decision

We give the node priority with weights, not limits:

- `system.slice` and `user.slice` get `CPUWeight=1000` and
  `IOWeight=10000` (guests: `qemu.slice` and the container slice stay at
  100). `system.slice` gets `MemoryLow=4G`.
- The OS disk uses the BFQ scheduler, persisted by a udev rule.
- The values are set in the node config and applied by
  `scripts/proxmox-node/resource-management.sh`. Details:
  [`docs/design/resource-management.md`](../design/resource-management.md).

Rejected:

- **Limits**: they waste idle capacity and need a per-guest value to tune.
- **Keeping `none`**: it gives the best throughput (run A) but no way to
  prioritise the node.

## Consequences

- The node's disk I/O wins over guests under contention (run C vs run A).
- Guest disk throughput drops, by 29 % (run C) to 53 % (run B) in the worst
  case measured. The user accepts this.
- A VM or container counts as one group. Between guests, BFQ shares per
  process, not per guest.
- `qemu.slice` passes only the `cpu`, `memory` and `pids` controllers to its
  children, so VMs have no per-VM `io.bfq.weight`.
- Not measured: fairness between several guests; only one VM was tested.
  Container cgroup paths are unconfirmed because no container was run.
- systemd does not write a changed drop-in value to a running slice, and
  removing a drop-in does not reset the value the kernel holds (the weight
  stayed after `systemctl revert`). Values, and the defaults on a revert,
  are written to the running slices.
- `system.slice` is created before the `bfq` module is registered, so
  systemd writes no `io.bfq.weight` to it at boot (measured: it stayed at
  100 after a reboot). A oneshot systemd unit, run after udev has set the
  scheduler, writes the values at every boot. This adds one managed unit;
  the boot image is unchanged.
- Not covered: network, backups, migration.
