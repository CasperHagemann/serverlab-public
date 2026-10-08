# Design: Networking

## Scope

Management network, VLANs, Linux bridges, and bonding. Node values are in `config/proxmox-nodes/<hostname>.env`; site subnets and gateways are in [`inventory/ip-plan.md`](../../inventory/ip-plan.md).

## Configuration

Two physically separate networks. One NIC per bridge, no bonding. The management network is untagged. The VM network is a tagged-only 802.1Q trunk.

### Management network

`NET_MGMT_IFACE` and `NET_MGMT_BRIDGE` name the NIC and the bridge of the management network (web UI, SSH, cluster comms), for example `nic0` and `vmbr0`. `NET_MGMT_CIDR` is the node address with prefix length and `NET_MGMT_GATEWAY` the gateway, for example `192.168.88.101/24` and `192.168.88.1`. The Proxmox installer configures this network. No script reads these keys; they record the installed state of the node.

### VM trunk network

`NET_VM_IFACE` and `NET_VM_BRIDGE` name the NIC and the bridge for guest traffic, for example `nic1` and `vmbr1`. `NET_VM_BRIDGE_COMMENT` is the bridge comment shown in Proxmox. The bridge has no node IP.

The NIC is connected to a trunk port on the external networking equipment. The bridge is VLAN aware (the "VLAN aware" setting in Proxmox). The external equipment drops untagged traffic, so every guest NIC on the bridge needs a VLAN tag. Gateways and DHCP for each VLAN are on the external equipment. Subnets, gateways and DHCP pools are in [`inventory/ip-plan.md`](../../inventory/ip-plan.md).

| VLAN | Interface          | Zone     |
| ---- | ------------------ | -------- |
| 100  | `vlan100-general`  | GENERAL  |
| 101  | `vlan101-dmz`      | DMZ      |
| 102  | `vlan102-frontend` | FRONTEND |
| 103  | `vlan103-backend`  | BACKEND  |

| Value of the `VM_*` keys                         | Effect                                                                                                                                               |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| NIC and bridge names                             | The bridge is created on that NIC                                                                                                                    |
| `NET_VM_BRIDGE_VLAN_AWARE` `1`                   | VLAN aware on: `bridge-vlan-aware yes` and `bridge-vids` are set; leftover `vmbr1v<N>` and `nic1.<N>` interfaces are deleted                         |
| `NET_VM_BRIDGE_VLAN_AWARE` `0`                   | VLAN aware off: the `bridge-vlan-aware` and `bridge-vids` lines are removed (Proxmox ignores `--bridge_vlan_aware 0`, so the script uses `--delete`) |
| `NET_VM_BRIDGE_VIDS` IDs and ranges              | The VLAN IDs of the bridge (`bridge-vids`), space-separated, within 2-4094, for example `2-4094`. Used only when VLAN aware is `1`                   |
| `NET_VM_BRIDGE_VIDS` empty                       | Same as `2-4094`, which Proxmox writes when the GUI field is blank                                                                                   |
| Bridge exists with other VLAN settings           | Only VLAN aware and `bridge-vids` are changed; ports and comment stay                                                                                |
| `NET_VM_BRIDGE_VIDS` unset, or another key unset | The script stops with an error                                                                                                                       |

### Switching VLAN aware

The node needs no reboot. In both modes the VLAN tag on a guest NIC selects its VLAN.

- VLAN aware off: for each tag in use, Proxmox creates `nic1.<N>` and `vmbr1v<N>` and connects the guest to `vmbr1v<N>`.
- VLAN aware on: guests connect directly to `vmbr1` and the port gets the VLAN. `nic1.<N>` and `vmbr1v<N>` would capture the tagged traffic first, so the script deletes those not defined in `/etc/network/interfaces`.
- After a switch, guests running on `vmbr1` need `qm stop` and `qm start`. A restart from inside the guest does not reconnect its NIC.
- Each applied change backs up `/etc/network/interfaces` to `interfaces.bak.<timestamp>`. The newest 5 backups are kept.

## Implementation

- The VM bridge is created or updated by [`scripts/proxmox-node/networking.sh`](../../scripts/proxmox-node/networking.sh). The script expects the management bridge to exist. It compares `/etc/network/interfaces` with the configuration and stops with an error if the staged change is identical to the current file.

## Verification

| Check                                                      | Expected result                         |
| ---------------------------------------------------------- | --------------------------------------- |
| `ip -br link show <NET_VM_BRIDGE>`                         | The bridge exists                       |
| `cat /sys/class/net/<NET_VM_BRIDGE>/bridge/vlan_filtering` | `1` (VLAN aware on), `0` (off)          |
| `grep bridge-vids /etc/network/interfaces`                 | `bridge-vids 2-4094` (VLAN aware on)    |
| `bridge vlan show dev <NET_VM_IFACE>`                      | The configured VLAN IDs (VLAN aware on) |
| `ip -br link \| grep -E 'vmbr1v\|nic1\.'`                  | Nothing (VLAN aware on)                 |
| `networking.sh --dry-run`                                  | Reports nothing to do                   |

## Decision records

None.

## Planned

None.
