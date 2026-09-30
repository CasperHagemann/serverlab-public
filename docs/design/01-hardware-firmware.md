# Design: Hardware & Firmware

> Reference: [`docs/inspiration/proxmox-guide.md`](../inspiration/proxmox-guide.md#1-hardware-and-firmware-preparation) (unvetted).

## Scope

CPU virtualization features (VT-x/VT-d, AMD-V/AMD-Vi), memory planning (ECC, capacity, hypervisor reservation), physical storage layout, and out-of-band management (iDRAC/iLO/IPMI).

Hardware values are recorded in [`inventory/hardware.md`](../../inventory/hardware.md).

## Configuration

None.

---

## Planned

> Not implemented.

| Item                    | Description                                    | Depends on |
| ----------------------- | ---------------------------------------------- | ---------- |
| Virtualization features | Required CPU virtualization and IOMMU settings | -          |
| Memory planning         | ECC, capacity, hypervisor reservation          | -          |
| Physical storage layout | Disk roles and layout                          | -          |
| Out-of-band management  | iDRAC/iLO/IPMI, where the hardware provides it | -          |
