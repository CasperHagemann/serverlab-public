# Design: Proxmox Install

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#2-install-proxmox-ve) (unvetted).

## Scope

Install configuration (hostname, management IP, gateway, DNS, timezone) and post-install tasks (updates, NTP, repositories).

## Configuration

| Setting       | Value                               |
| ------------- | ----------------------------------- |
| Node          | `pve.kiwik.org` (Minisforum MS-A2)  |
| Hostname      | `pve.kiwik.org`                     |
| Management IP | 192.168.88.101/24 on `nic0`/`vmbr0` |
| Gateway / DNS | 192.168.88.1                        |

See [`inventory/ip-plan.md`](../../inventory/ip-plan.md) and [`03-networking.md`](03-networking.md).

### NTP

The node uses exactly the servers listed in `NTP_SERVERS` (an array in the node config, `config/proxmox-nodes/<hostname>.env`):

| Setting       | Value                                                                  |
| ------------- | ---------------------------------------------------------------------- |
| `NTP_SERVERS` | `0.pool.ntp.org`, `1.pool.ntp.org`, `2.pool.ntp.org`, `3.pool.ntp.org` |
| Empty `()`    | Reverts the node to the OS default chrony configuration                |
| Unset         | The script stops with an error (a typo cannot silently reset the node) |

## Implementation

[`scripts/proxmox-node/05-proxmox-install.sh`](../../scripts/proxmox-node/05-proxmox-install.sh) configures chrony:

- Writes `/etc/chrony/sources.d/ntp-servers.sources` with one `server <name> iburst` line per entry.
- Comments out the active `pool`/`server` lines and `sourcedir /run/chrony-dhcp` in `/etc/chrony/chrony.conf`, so only the listed servers are used (no DHCP-provided servers).
- Before the first change, saves the original `chrony.conf` as `/etc/chrony/chrony.conf.orig`. It is never overwritten and is used as the base for later runs and for the revert.
- With an empty `NTP_SERVERS`, restores `chrony.conf` from `.orig` and removes the sources file.
- Requires a `sourcedir /etc/chrony/sources.d` line in the base config; otherwise it stops.
- Backs up changed files with a timestamp, restarts chrony, and verifies: the files match, chrony is active, and it has exactly as many sources as `NTP_SERVERS`. Failing to synchronise within about a minute only warns. On failure it prints manual undo steps and does not roll back.

Script structure: [`scripts/README.md`](../../scripts/README.md) and [ADR-0003](../decisions/0003-proxmox-node-script-structure-and-conventions.md).

## Verification

| Check                             | Expected result                             |
| --------------------------------- | ------------------------------------------- |
| `chronyc sources`                 | Lists only the servers in `NTP_SERVERS`     |
| `chronyc tracking`                | `Leap status : Normal`, small offset        |
| `05-proxmox-install.sh --dry-run` | Reports "NTP configuration already matches" |

---

## Planned

> Not implemented.

| Item                 | Description              | Depends on |
| -------------------- | ------------------------ | ---------- |
| Timezone             | Set node timezone        | -          |
| Updates              | Apply package updates    | -          |
| Package repositories | Repository configuration | -          |
