# Design: Backup & Recovery

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#7-backup-strategy) (unvetted).

## Scope

Backup strategy, Proxmox Backup Server, retention policy, offsite copies.

## Configuration

None. Local backups on `local-data` are described in [`04-storage.md`](04-storage.md).

---

## Planned

> Not implemented.

| Item                  | Description                                           | Depends on            |
| --------------------- | ----------------------------------------------------- | --------------------- |
| Backup strategy       | 3-2-1 rule                                            | -                     |
| Proxmox Backup Server | PBS on a second host (see Backups in `04-storage.md`) | Second host (phase 2) |
| Retention policy      | Retention periods                                     | -                     |
| Offsite copies        | Copy outside the site                                 | -                     |
