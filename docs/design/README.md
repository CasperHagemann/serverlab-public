# Design Docs Index

Design documents for each Proxmox-node design area. Unlike
[`docs/decisions/`](../decisions/), these describe the _current_ state and are
updated as the design changes. Each doc has a Configuration section for what
is live and a separate Planned section for what is not implemented.

| #   | Doc                                                       | Purpose                                                                           | Status      |
| --- | --------------------------------------------------------- | --------------------------------------------------------------------------------- | ----------- |
| 00  | [Overview](00-overview.md)                                | Overall layered architecture and how the design docs map to it                    | Not started |
| 01  | [Hardware & Firmware](01-hardware-firmware.md)            | Hardware selection, firmware/BIOS configuration                                   | Not started |
| 02  | [Proxmox Install](02-proxmox-install.md)                  | Install and post-install host configuration (hostname, IP, time zone, NTP, repos) | Implemented |
| 03  | [Networking](03-networking.md)                            | Management network, VLANs, Linux bridges, bonding                                 | Implemented |
| 04  | [Storage](04-storage.md)                                  | Storage pools/layout for the Proxmox node                                         | Implemented |
| 05  | [Security & Access](05-security-access.md)                | Access control, hardening, authentication                                         | Not started |
| 06  | [Backup & Recovery](06-backup-recovery.md)                | Backup strategy and recovery procedures                                           | Not started |
| 07  | [Monitoring](07-monitoring.md)                            | Node monitoring/alerting                                                          | Not started |
| 08  | [High Availability & Clustering](08-high-availability.md) | Phase 2 clustering and hardware-level failover                                    | Not started |
| 09  | [Resource Management](09-resource-management.md)          | Node priority over guests for CPU, disk I/O and memory (weights)                  | Not started |
