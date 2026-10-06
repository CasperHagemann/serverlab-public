# Design: Backup & Recovery

## Scope

Backup strategy, Proxmox Backup Server, retention policy, offsite copies.

## Configuration

None.

---

## Planned

> Not implemented.

| Item                      | Description                                                                 | Depends on            |
| ------------------------- | --------------------------------------------------------------------------- | --------------------- |
| Backup strategy           | 3-2-1 rule                                                                  | -                     |
| Proxmox Backup Server     | PBS on a second host                                                        | Second host (phase 2) |
| Retention policy          | Retention periods                                                           | -                     |
| Offsite copies            | Copy outside the site                                                       | -                     |
| Guest backups             | Scheduled backups of VMs and containers (`vzdump` or Proxmox Backup Server) | -                     |
| Node configuration backup | Backup of the node and cluster configuration (`/etc/pve`)                   | -                     |
