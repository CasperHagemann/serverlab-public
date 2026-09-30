# Design: Proxmox Install

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#2-install-proxmox-ve) (unvetted).

## Scope

Install configuration (hostname, management IP, gateway, DNS, timezone) and post-install tasks (updates, NTP, repositories).

## Configuration

| Setting       | Value                               |
| ------------- | ----------------------------------- |
| Host          | `pve.kiwik.org` (Minisforum MS-A2)  |
| Hostname      | `pve.kiwik.org`                     |
| Management IP | 192.168.88.101/24 on `nic0`/`vmbr0` |
| Gateway / DNS | 192.168.88.1                        |

See [`inventory/ip-plan.md`](../../inventory/ip-plan.md) and [`03-networking.md`](03-networking.md).

---

## Planned

> Not implemented.

| Item                 | Description                        | Depends on |
| -------------------- | ---------------------------------- | ---------- |
| Timezone             | Set host timezone                  | -          |
| Updates              | Apply package updates              | -          |
| NTP                  | Time synchronisation configuration | -          |
| Package repositories | Repository configuration           | -          |
