# Design: Networking

## Scope

Management network, VLANs, Linux bridges, and bonding. Node values are in `config/proxmox-nodes/<hostname>.env`; site subnets and gateways are in [`inventory/ip-plan.md`](../../inventory/ip-plan.md).

## Configuration

Two physically separate networks. One NIC per bridge, no bonding. Both networks are untagged.

### Management network

`NET_MGMT_IFACE` and `NET_MGMT_BRIDGE` name the NIC and the bridge of the management network (web UI, SSH, cluster comms), for example `nic0` and `vmbr0`. `NET_MGMT_CIDR` is the node address with prefix length and `NET_MGMT_GATEWAY` the gateway, for example `192.168.88.101/24` and `192.168.88.1`. The Proxmox installer configures this network. No script reads these keys; they record the installed state of the node.

### General VM network

`NET_VM_IFACE` and `NET_VM_BRIDGE` name the NIC and the bridge for guest traffic, for example `nic1` and `vmbr1`. `NET_VM_BRIDGE_COMMENT` is the bridge comment shown in Proxmox. The bridge has no node IP.

| Value of the `VM_*` keys | Effect                            |
| ------------------------ | --------------------------------- |
| NIC and bridge names     | The bridge is created on that NIC |
| Any key unset            | The script stops with an error    |

## Implementation

- The VM bridge is created by [`scripts/proxmox-node/networking.sh`](../../scripts/proxmox-node/networking.sh). The script expects the management bridge to exist.
- Script structure: [`scripts/README.md`](../../scripts/README.md) and [ADR-0008](../decisions/0008-proxmox-node-script-contract.md).

## Verification

| Check                              | Expected result       |
| ---------------------------------- | --------------------- |
| `ip -br link show <NET_VM_BRIDGE>` | The bridge exists     |
| `networking.sh --dry-run`          | Reports nothing to do |
