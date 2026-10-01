# Design: Networking

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#3-networking-design) (unvetted).

## Scope

Management network, VLANs, Linux bridges, and bonding. Concrete values: [`inventory/networks.md`](../../inventory/networks.md) and [`inventory/ip-plan.md`](../../inventory/ip-plan.md).

## Configuration

Two physically separate networks. One NIC per bridge, no bonding. Both networks are untagged.

| Bridge  | NIC    | Purpose                                     | Subnet           | Node IP        | Gateway / DNS                      |
| ------- | ------ | ------------------------------------------- | ---------------- | -------------- | ---------------------------------- |
| `vmbr0` | `nic0` | Management (web UI, SSH, cluster comms)     | 192.168.88.0/24  | 192.168.88.101 | 192.168.88.1                       |
| `vmbr1` | `nic1` | General VM (guest traffic only, no node IP) | 192.168.100.0/24 | -              | 192.168.100.1 (external equipment) |

## Implementation

- `vmbr0` is created by the Proxmox installer.
- `vmbr1` is created by [`scripts/proxmox-node/10-network.sh`](../../scripts/proxmox-node/10-network.sh). The script expects `vmbr0` to exist.
- Script structure: [`scripts/README.md`](../../scripts/README.md) and [ADR-0003](../decisions/0003-proxmox-node-script-structure-and-conventions.md).

## Verification

| Check                     | Expected result       |
| ------------------------- | --------------------- |
| `ip -br link show vmbr1`  | `vmbr1` exists        |
| `10-network.sh --dry-run` | Reports nothing to do |
