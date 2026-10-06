# Design Docs Index

One design doc per Proxmox-node design area. Unlike
[`docs/decisions/`](../decisions/), these describe the _current_ state and are
updated as the design changes. Every doc has the sections Scope, Configuration,
Decision records and Planned, in that order. Docs for implemented areas
also have Constraints (if any), Implementation and Verification, between
Configuration and Decision records. Scripts follow
[ADR-0008](../decisions/0008-proxmox-node-script-contract.md), so the docs do not
repeat it. Empty Decision records and Planned sections say `None.`; a Planned
section with content starts with `> Not implemented.`.

The areas are independent and have no run order. An area with a script has a
script of the same name in [`scripts/proxmox-node/`](../../scripts/proxmox-node/).

| Doc                                           | Script                   | Purpose                                                          | Status      |
| --------------------------------------------- | ------------------------ | ---------------------------------------------------------------- | ----------- |
| [Base System](base-system.md)                 | `base-system.sh`         | Time zone, NTP, package repositories                             | Implemented |
| [Networking](networking.md)                   | `networking.sh`          | Management network, VLANs, Linux bridges, bonding                | Implemented |
| [Storage](storage.md)                         | `storage.sh`             | Storage pools/layout for the Proxmox node                        | Implemented |
| [Resource Management](resource-management.md) | `resource-management.sh` | Node priority over guests for CPU, disk I/O and memory (weights) | Implemented |
| [Security & Access](security-access.md)       | -                        | Access control, hardening, authentication                        | Not started |
| [Backup & Recovery](backup-recovery.md)       | -                        | Backup strategy and recovery procedures                          | Not started |
| [Monitoring](monitoring.md)                   | -                        | Node monitoring/alerting                                         | Not started |
| [Clustering](clustering.md)                   | -                        | Multi-node cluster and hardware-level failover                   | Not started |

## Where facts live

Each fact has one owner; see
[ADR-0003](../decisions/0003-repository-layout-and-sources-of-truth.md).
A short reason for a node value goes as a comment next to it in the `.env`.

## Format of a configuration section

Each key, or group of related keys, gets a short description that gives the
current value as an example, followed by a table of what each kind of value
does. Verification checks use `<KEY>` instead of the value.

```markdown
### <Topic>

`KEY` is <what it is>, for example `<current value>`.

| Value of `KEY` | Effect |
| -------------- | ------ |
| <normal case>  | ...    |
| Empty `""`     | ...    |
| Unset          | ...    |
```

Fixed behaviour built into a script (paths, mount options) is plain text, not a
node value.

## Sources

Official documentation for the tools in use. Versions are in
[`inventory/hardware.md`](../../inventory/hardware.md).

- Proxmox VE: <https://pve.proxmox.com/pve-docs/>, API viewer
  <https://pve.proxmox.com/pve-docs/api-viewer/>
- Debian manpages, including systemd (use `trixie`):
  <https://manpages.debian.org/trixie/>
- Linux cgroup v2: <https://docs.kernel.org/admin-guide/cgroup-v2.html>
- btrfs: <https://btrfs.readthedocs.io/en/latest/>
- chrony: <https://chrony-project.org/documentation.html>
- Google Shell Style Guide: <https://google.github.io/styleguide/shellguide.html>
- ShellCheck wiki: <https://www.shellcheck.net/wiki/>
- bats-core: <https://bats-core.readthedocs.io/en/stable/>
