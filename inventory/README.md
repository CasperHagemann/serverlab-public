# Inventory

Facts about the lab that no script sets: the hardware, and the site network plan.

| File                         | Contents                                                              |
| ---------------------------- | --------------------------------------------------------------------- |
| [`hardware.md`](hardware.md) | Node hardware: model, CPU, RAM, disks, NICs, firmware, SMART baseline |
| [`ip-plan.md`](ip-plan.md)   | Site subnets and gateways                                             |

Values a script applies (bridges, IPs, storage, time zone) belong in
`config/proxmox-nodes/<hostname>.env`, not here.
