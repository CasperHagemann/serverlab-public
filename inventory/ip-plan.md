# IP Plan

Site networks and addresses that no node sets. Node addresses are in `config/proxmox-nodes/<hostname>.env`.

| Network    | VLAN     | Interface          | Zone     | Subnet           | Gateway / DNS                      | DHCP pool |
| ---------- | -------- | ------------------ | -------- | ---------------- | ---------------------------------- | --------- |
| Management | untagged | —                  | —        | 192.168.88.0/24  | 192.168.88.1 (external equipment)  | —         |
| General    | 100      | `vlan100-general`  | GENERAL  | 192.168.100.0/24 | 192.168.100.1 (external equipment) | .10–.254  |
| DMZ        | 101      | `vlan101-dmz`      | DMZ      | 192.168.101.0/24 | 192.168.101.1 (external equipment) | .10–.254  |
| Frontend   | 102      | `vlan102-frontend` | FRONTEND | 192.168.102.0/24 | 192.168.102.1 (external equipment) | .10–.254  |
| Backend    | 103      | `vlan103-backend`  | BACKEND  | 192.168.103.0/24 | 192.168.103.1 (external equipment) | .10–.254  |

VLANs 100–103 arrive tagged on the VM trunk (`vmbr1`); untagged traffic is dropped by the external equipment. In each VLAN subnet, .2–.9 is outside the DHCP pool.
