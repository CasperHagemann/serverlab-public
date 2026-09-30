# IP Plan

Source of truth for IP address allocations.

## Management

| Purpose                | IP                | Notes                                         |
| ---------------------- | ----------------- | --------------------------------------------- |
| `pve.kiwik.org` (host) | 192.168.88.101/24 | Proxmox host management IP, on `vmbr0`/`nic0` |
| Gateway / DNS          | 192.168.88.1      | External network equipment                    |

## General VM network

| Purpose       | IP            | Notes                      |
| ------------- | ------------- | -------------------------- |
| Gateway / DNS | 192.168.100.1 | External network equipment |

## Reservations

| Range         | Purpose                                     |
| ------------- | ------------------------------------------- |
| 192.168.88.1  | Management gateway/DNS (external equipment) |
| 192.168.100.1 | General VM gateway/DNS (external equipment) |

See [`networks.md`](networks.md) for VLAN/bridge details.
