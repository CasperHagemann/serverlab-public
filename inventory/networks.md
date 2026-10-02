# Network Inventory

Networks, bridges, and interface names (see also [`docs/design/03-networking.md`](../docs/design/03-networking.md)).

## VLANs

| VLAN     | Purpose    | Subnet           | Notes                                                         |
| -------- | ---------- | ---------------- | ------------------------------------------------------------- |
| Untagged | Management | 192.168.88.0/24  | Web UI, SSH, cluster comms; gw/DNS 192.168.88.1               |
| Untagged | General VM | 192.168.100.0/24 | Guest traffic only; gw/DNS 192.168.100.1 (external equipment) |

## Bridges / Bonding

No NIC bonding. Two bridges, each mapped to a single physical NIC:

| Bridge  | Physical NIC | Purpose    | Subnet           |
| ------- | ------------ | ---------- | ---------------- |
| `vmbr0` | `nic0`       | Management | 192.168.88.0/24  |
| `vmbr1` | `nic1`       | General VM | 192.168.100.0/24 |

## Interface naming

Physical NIC names, recorded per node so scripts can reference this
file/config rather than hardcoding names.

| Node            | Management interface | General VM interface | Notes                                  |
| --------------- | -------------------- | -------------------- | -------------------------------------- |
| `pve.kiwik.org` | `nic0` (`igc`)       | `nic1` (`r8169`)     | See `inventory/hardware.md` for detail |
