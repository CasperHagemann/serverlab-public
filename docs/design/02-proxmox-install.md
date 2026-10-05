# Design: Proxmox Install

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#2-install-proxmox-ve) (unvetted).

## Scope

Install configuration (hostname, management IP, gateway, DNS, timezone) and post-install tasks (NTP, package repositories).

## Configuration

| Setting       | Value                               |
| ------------- | ----------------------------------- |
| Node          | `pve.kiwik.org` (Minisforum MS-A2)  |
| Hostname      | `pve.kiwik.org`                     |
| Management IP | 192.168.88.101/24 on `nic0`/`vmbr0` |
| Gateway / DNS | 192.168.88.1                        |

See [`inventory/ip-plan.md`](../../inventory/ip-plan.md) and [`03-networking.md`](03-networking.md).

### Time zone

`TIMEZONE` (node config, `config/proxmox-nodes/<hostname>.env`) is an IANA zone name. The zone follows daylight saving time automatically.

| Setting    | Value                                                                     |
| ---------- | ------------------------------------------------------------------------- |
| `TIMEZONE` | `Europe/Copenhagen`                                                       |
| Empty `""` | Reverts to the zone saved in `/etc/timezone.orig` before the first change |
| Unset      | The script stops with an error (a typo cannot silently change the node)   |

### NTP

The node uses exactly the servers listed in `NTP_SERVERS` (an array in the node config, `config/proxmox-nodes/<hostname>.env`):

| Setting       | Value                                                                  |
| ------------- | ---------------------------------------------------------------------- |
| `NTP_SERVERS` | `0.pool.ntp.org`, `1.pool.ntp.org`, `2.pool.ntp.org`, `3.pool.ntp.org` |
| Empty `()`    | Reverts the node to the OS default chrony configuration                |
| Unset         | The script stops with an error (a typo cannot silently reset the node) |

### Package repositories

No Proxmox subscription is used, so both enterprise repositories are always disabled (never deleted). Two settings in the node config choose what replaces them:

| Setting           | Value               | Effect                                                                                      |
| ----------------- | ------------------- | ------------------------------------------------------------------------------------------- |
| `PVE_REPOSITORY`  | `"no-subscription"` | `pve-enterprise.sources` disabled; `proxmox.sources` (pve-no-subscription) written          |
| `PVE_REPOSITORY`  | `""`                | Restores the stock `pve-enterprise.sources`; removes `proxmox.sources`                      |
| `CEPH_REPOSITORY` | `"disabled"`        | `ceph.sources` disabled; no Ceph repository added (no Ceph on this node)                    |
| `CEPH_REPOSITORY` | `"no-subscription"` | `ceph.sources` disabled; `ceph-no-subscription.sources` written (for a future Ceph cluster) |
| `CEPH_REPOSITORY` | `""`                | Restores the stock `ceph.sources`; removes `ceph-no-subscription.sources`                   |
| Either unset      |                     | The script stops with an error (a typo cannot silently change the node)                     |

`pve.kiwik.org`: `PVE_REPOSITORY="no-subscription"`, `CEPH_REPOSITORY="disabled"`. `debian.sources` is not touched.

## Implementation

[`scripts/proxmox-node/05-proxmox-install.sh`](../../scripts/proxmox-node/05-proxmox-install.sh) runs a time zone step, an NTP step and a package repositories step. Each step shows its plan; one confirmation covers all steps with changes, and only steps with changes are applied.

Time zone:

- Sets the zone with `pvesh set /nodes/<node>/time --timezone <zone>`.
- Before the first change, saves the previous zone name as `/etc/timezone.orig`. It is never overwritten.
- With an empty `TIMEZONE`, sets the zone saved in `/etc/timezone.orig`; if the file does not exist, nothing is changed.
- Stops if the zone does not exist under `/usr/share/zoneinfo`, or if the hardware clock is set to local time (`timedatectl set-local-rtc 0` sets it to UTC).
- Verifies the zone and that the hardware clock is UTC. On failure it prints the previous zone and the restore command, and does not roll back.

NTP (chrony):

- Writes `/etc/chrony/sources.d/ntp-servers.sources` with one `server <name> iburst` line per entry.
- Comments out the active `pool`/`server` lines and `sourcedir /run/chrony-dhcp` in `/etc/chrony/chrony.conf`, so only the listed servers are used (no DHCP-provided servers).
- Before the first change, saves the original `chrony.conf` as `/etc/chrony/chrony.conf.orig`. It is never overwritten and is used as the base for later runs and for the revert.
- With an empty `NTP_SERVERS`, restores `chrony.conf` from `.orig` and removes the sources file.
- Requires a `sourcedir /etc/chrony/sources.d` line in the base config; otherwise it stops.
- Backs up changed files with a timestamp, restarts chrony, and verifies: the files match, chrony is active, and it has exactly as many sources as `NTP_SERVERS`. Failing to synchronise within about a minute only warns. On failure it prints manual undo steps and does not roll back.

Package repositories (deb822 files in `/etc/apt/sources.list.d/`):

- Disabling adds `Enabled: no` to the stock enterprise file; the file is kept.
- The no-subscription files use the suite and keyring of the stock enterprise file. The Ceph no-subscription URI is derived from the stock `ceph.sources` URI (`enterprise.proxmox.com` to `download.proxmox.com`), so the Ceph release is never hardcoded.
- Before the first change, saves each stock enterprise file in `/etc/apt/sources.list.orig/`. It is never overwritten and is the base for later runs and for the revert. Timestamped backups go in the same directory, because apt reports stray files in `sources.list.d`.
- Stops if the stock file is missing, its suite is not this OS release, its keyring does not exist, or (for the Ceph no-subscription value) its URI is not a Proxmox Ceph enterprise URI.
- Verifies the files match, then runs `apt-get update`: any `E:`/`Err:` line fails; `W:` lines only warn. After a revert an enterprise repository is enabled again and returns 401 without a subscription key, so errors that mention `enterprise.proxmox.com` only warn, and only while such a repository is enabled. On failure it prints manual undo steps and does not roll back.

Script structure: [`scripts/README.md`](../../scripts/README.md) and [ADR-0003](../decisions/0003-proxmox-node-script-structure-and-conventions.md).

## Verification

| Check                             | Expected result                                       |
| --------------------------------- | ----------------------------------------------------- |
| `timedatectl`                     | `Time zone: Europe/Copenhagen`, `RTC in local TZ: no` |
| `chronyc sources`                 | Lists only the servers in `NTP_SERVERS`               |
| `chronyc tracking`                | `Leap status : Normal`, small offset                  |
| `apt-get update`                  | No errors; no enterprise repository contacted         |
| `05-proxmox-install.sh --dry-run` | Reports "Nothing to do."                              |
