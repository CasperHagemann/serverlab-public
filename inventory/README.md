# Inventory

Source of truth for this lab's physical hardware, networks, and IP
allocations. Scripts read values from here rather than hardcoding them —
see [`scripts/README.md`](../scripts/README.md#conventions), point 5.

## Files

| File                         | Contents                                                   |
| ---------------------------- | ---------------------------------------------------------- |
| [`hardware.md`](hardware.md) | Physical node inventory (CPU, RAM, storage, management IP) |
| [`networks.md`](networks.md) | VLANs, bridges/bonding, and interface naming per host      |
| [`ip-plan.md`](ip-plan.md)   | Concrete IP address allocations                            |

## Relationship to `docs/design/`

`docs/design/` describes _intended_ architecture and reasoning; `inventory/`
records the _concrete_ values that implement it (actual IPs, VLAN numbers,
NIC names). Design docs link to the relevant inventory file where a design
decision produces a concrete value to record.

Host-specific values (NIC names, disk device paths, VLAN IDs) differ per
host — record them here per host, as already structured in `hardware.md`
and `networks.md`.
