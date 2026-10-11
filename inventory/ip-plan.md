# IP Plan

Site networks and addresses that no node sets. Node addresses are in `config/proxmox-nodes/<hostname>.env`.

| Network       | VLAN     | Interface          | Zone     | Subnet           | Gateway / DNS                      | DHCP pool |
| ------------- | -------- | ------------------ | -------- | ---------------- | ---------------------------------- | --------- |
| Management    | untagged | —                  | —        | 192.168.88.0/24  | 192.168.88.1 (external equipment)  | —         |
| General       | 100      | `vlan100-general`  | GENERAL  | 192.168.100.0/24 | 192.168.100.1 (external equipment) | .10–.254  |
| Edge          | 110      | `vlan110-edge`     | EDGE     | 192.168.110.0/24 | 192.168.110.1 (external equipment) | .10–.254  |
| Services      | 120      | `vlan120-services` | SERVICES | 192.168.120.0/24 | 192.168.120.1 (external equipment) | .10–.254  |
| Data          | 130      | `vlan130-data`     | DATA     | 192.168.130.0/24 | 192.168.130.1 (external equipment) | .10–.254  |
| Remote access | 140      | `vlan140-remote`   | REMOTE   | 192.168.140.0/24 | 192.168.140.1 (external equipment) | .10–.254  |

VLANs 100 and 110–140 arrive tagged on the VM trunk (`NET_VM_BRIDGE`); untagged traffic is dropped by the external equipment. In each VLAN subnet, .2–.9 is outside the DHCP pool.
