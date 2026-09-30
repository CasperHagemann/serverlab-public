# Hardware Inventory

Physical hardware used in this lab.

## Nodes

| Hostname        | Role                      | Model            | CPU                          | RAM           | Mgmt (BMC) IP |
| --------------- | ------------------------- | ---------------- | ---------------------------- | ------------- | ------------- |
| `pve.kiwik.org` | Proxmox host (bare metal) | Minisforum MS-A2 | AMD Ryzen 9 9955HX (16C/32T) | 29 GiB usable | N/A (no BMC)  |

## `pve.kiwik.org` (MS-A2)

### Firmware

| Component | Version    | Date       |
| --------- | ---------- | ---------- |
| BIOS      | AMI 1.02   | 2025-06-16 |
| NVMe      | `P4ER3B31` | —          |

### Storage

| Device         | Model                        | Capacity | Partition(s)     | Filesystem | Use                    |
| -------------- | ---------------------------- | -------- | ---------------- | ---------- | ---------------------- |
| `/dev/nvme0n1` | Kingston `OM8TAP41024K1-A00` | 1 TB     | `nvme0n1p1`-`p3` | btrfs      | Proxmox OS (~100 GB)   |
| `/dev/nvme0n1` | Kingston `OM8TAP41024K1-A00` | 1 TB     | `nvme0n1p4`      | btrfs      | `local-data` (~853 GB) |

### SMART / error baseline

Recorded at first boot. An extended self-test and a `btrfs scrub` completed
with no errors, and the counts did not change afterwards.

| Metric                          | Source                   | Value |
| ------------------------------- | ------------------------ | ----- |
| Media and Data Integrity Errors | `smartctl -a /dev/nvme0` | 2     |
| Unsafe Shutdowns                | `smartctl -a /dev/nvme0` | 7     |
| `RxErr` (kernel log)            | `journalctl -k`          | 2     |

### Virtualization

| Feature         | Status                                           |
| --------------- | ------------------------------------------------ |
| AMD-V           | Present                                          |
| AMD-Vi (IOMMU)  | Active; PCI devices in separate groups           |
| PCI passthrough | Possible                                         |
| x2AVIC          | Unsupported (firmware bug reported by `kvm_amd`) |

### NICs

| Name     | Driver  | Port      | Use                                       |
| -------- | ------- | --------- | ----------------------------------------- |
| `nic0`   | `igc`   | 2.5G RJ45 | Management (`vmbr0`); cabled, links at 1G |
| `nic1`   | `r8169` | 2.5G RJ45 | General VM (`vmbr1`); not cabled          |
| `nic2`   | `i40e`  | 10G SFP+  | Unused (no SFP modules)                   |
| `nic3`   | `i40e`  | 10G SFP+  | Unused (no SFP modules)                   |
| `wlp6s0` | Wi-Fi   | —         | Unused                                    |
