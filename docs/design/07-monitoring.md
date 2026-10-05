# Design: Monitoring

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#6-monitoring) (unvetted).

## Scope

Hardware monitoring (temperatures, fans, disk health), node monitoring (CPU, RAM, storage, network), and monitoring platform.

## Configuration

None.

---

## Planned

> Not implemented.

| Item                | Description                                                                                                                 | Depends on |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------- |
| Hardware monitoring | Temperatures, fans, disk health                                                                                             | -          |
| Node monitoring     | CPU, RAM, storage, network                                                                                                  | -          |
| Monitoring platform | Platform selection and alerting                                                                                             | -          |
| Notifications       | Notification targets and the `root@pam` email address, for update checks, backup failures and disk health (`smartmontools`) | -          |
