# Proxmox Deployment Guide: From Bare Metal to Virtual Machines and Containers

> **Status: unvetted / inspiration only.**
> This document is the original placeholder content from the project's
> initial `README.md`. It has not been reviewed, corrected, or endorsed as
> this project's actual design. Treat it as raw inspiration/reference
> material only. Real, vetted design decisions for this repo live in
> [`docs/design/`](../design/) and [`docs/decisions/`](../decisions/).

## Overview

If you already have:

- A physical server
- Rack space
- Power
- Cooling
- Network connectivity
- A functioning datacenter

Then the journey from bare metal to running workloads on Proxmox VE can be broken into several major layers.

```text
Hardware
│
├── Firmware (BIOS/iDRAC/iLO/IPMI)
│
├── Host OS (Proxmox)
│
├── Storage
│
├── Networking
│
├── Security & Access
│
├── Backup & Recovery
│
├── Monitoring
│
└── Virtualization Layer
    ├── Virtual Machines
    └── Containers
```

---

# 1. Hardware and Firmware Preparation

Before installing Proxmox, validate the server hardware and firmware configuration.

## CPU Virtualization

Enable hardware virtualization features:

### Intel

- VT-x
- VT-d

### AMD

- AMD-V
- AMD-Vi

These are required for:

- Hardware-assisted virtualization
- PCI passthrough
- GPU passthrough
- High-performance VM workloads

## Memory Planning

Determine:

- ECC vs non-ECC memory
- Total available RAM
- Hypervisor reservation

Example:

```text
Total RAM: 256 GB

Reserved for Proxmox Host:
16 GB

Available for Workloads:
240 GB
```

## Storage Layout

Plan storage before installation.

Example:

```text
2x SSD
 └── RAID1
     └── Proxmox OS

4x NVMe
 └── ZFS Pool
     └── VM Storage

Backup Storage
 └── Separate NAS/Object Storage
```

## Out-of-Band Management

Configure platform management interfaces:

- Dell iDRAC
- HPE iLO
- Lenovo XClarity
- Generic IPMI

Benefits:

- Remote console access
- Remote power control
- Hardware monitoring
- Firmware management
- BIOS access without physical presence

---

# 2. Install Proxmox VE

Install Proxmox VE on the server.

Typical configuration:

```text
Hostname
Management IP
Gateway
DNS
Timezone
```

Example:

```text
Hostname: pve01.company.local
IP:       10.1.10.20
Gateway:  10.1.10.1
```

Post-installation tasks:

- Update repositories
- Apply updates
- Configure NTP
- Configure subscriptions (if applicable)

---

# 3. Networking Design

Networking is one of the most important architectural decisions.

## Management Network

Used for:

- Web interface
- SSH
- Cluster communication

Example:

```text
VLAN 10

10.1.10.20
```

## VM and Application Networks

Separate workloads into VLANs.

Example:

```text
VLAN 20 - Server Infrastructure
VLAN 30 - Applications
VLAN 40 - DMZ
VLAN 50 - Storage
VLAN 60 - Backup
```

Benefits:

- Isolation
- Security
- Easier troubleshooting
- Better traffic control

## Linux Bridges

Proxmox uses Linux bridges to connect guests to networks.

Example:

```text
vmbr0
 └── Management

vmbr1
 └── Workloads

vmbr2
 └── Storage
```

## Network Bonding

For redundancy and higher throughput.

Example:

```text
eth0
eth1

Bond0
 └── LACP Bond
```

Advantages:

- Link redundancy
- Increased bandwidth
- Improved resilience

---

# 4. Storage Architecture

Storage design directly impacts performance and availability.

## Local Storage

Suitable for:

- Labs
- Small deployments
- Single-node installations

Common filesystems:

- ZFS
- ext4
- XFS

## Shared Storage

Used when running multiple Proxmox hosts.

Examples:

- NFS
- iSCSI
- Ceph
- Fibre Channel SAN

Benefits:

- Live migration
- High availability
- Shared workload access

## ZFS

Often the preferred choice.

Features:

- End-to-end checksums
- Compression
- Snapshots
- Replication
- Self-healing

Example:

```text
tank/vm-storage
```

Recommended:

```text
compression=lz4
```

---

# 5. Security Baseline

Secure the hypervisor before deploying workloads.

## Access Control

Avoid:

```text
Root SSH Password Login
```

Prefer:

```text
SSH Keys
```

Use role-based administration whenever possible.

## Firewall Configuration

### Datacenter Firewall

Global rules for all nodes.

### Node Firewall

Host protections.

### VM Firewall

Guest-level protections.

## Multi-Factor Authentication

Enable MFA for all administrators.

Options:

- TOTP
- Microsoft Authenticator
- Hardware security keys

---

# 6. Monitoring

Monitoring should be implemented immediately.

## Hardware Monitoring

Track:

- CPU temperature
- Fans
- Power supplies
- Disk health
- RAID status

## Host Monitoring

Track:

- CPU utilization
- Memory usage
- Storage consumption
- Network performance

## Workload Monitoring

Track:

- VM health
- Application health
- Capacity trends

Common monitoring platforms:

- Prometheus
- Grafana
- Zabbix
- PRTG
- CheckMK

---

# 7. Backup Strategy

Backups are critical.

Follow the 3-2-1 Rule:

```text
3 Copies of Data

2 Different Storage Types

1 Offsite Copy
```

## Proxmox Backup Server (PBS)

Recommended backup solution.

Features:

- Deduplication
- Incremental backups
- Scheduling
- Fast restores
- Efficient retention policies

Example:

```text
VM
 ↓
Proxmox Backup Server
 ↓
Offsite Replication
```

---

# 8. Virtual Machine Design

After infrastructure configuration, begin creating virtual machines.

## Templates

Create golden images.

Examples:

- Windows Server
- Ubuntu LTS
- Debian
- Rocky Linux

Benefits:

- Consistency
- Faster provisioning
- Standardized configuration

## VM Sizing

### Small Application Server

```text
2 vCPU
4 GB RAM
60 GB Storage
```

### Database Server

```text
8 vCPU
32 GB RAM
500 GB SSD
```

Avoid significant overprovisioning.

## CPU Configuration

Consider:

- Sockets
- Cores
- NUMA
- CPU Type

Recommended:

```text
CPU Type = host
```

for maximum performance.

## Memory Configuration

Options:

### Static Memory

Dedicated allocation.

### Ballooning

Dynamic memory management.

Pros:

- Better consolidation
- Higher resource utilization

## Disk Configuration

For most workloads:

```text
VirtIO SCSI
```

provides excellent performance.

---

# 9. Container Strategy

Proxmox supports Linux Containers (LXC).

Ideal for:

- Monitoring systems
- DNS services
- Reverse proxies
- Lightweight applications
- Utility services

Examples:

- Grafana
- Prometheus
- Pi-hole
- NGINX
- GitLab Runner

## LXC vs Virtual Machines

### LXC Advantages

- Lightweight
- Fast startup
- Efficient resource usage

### LXC Disadvantages

- Shared kernel
- Reduced isolation

### VM Advantages

- Strong isolation
- Supports any operating system
- Better security boundaries

### VM Disadvantages

- Higher resource consumption
- Longer startup times

### General Guideline

```text
Infrastructure Services → LXC

Business Applications → VM
```

---

# 10. Docker and Kubernetes

These often sit on top of the virtualization layer.

## Recommended Practice

Avoid:

```text
Docker directly on the Proxmox host
```

Prefer:

```text
Docker inside a VM
```

or

```text
Kubernetes inside VMs
```

Example:

```text
Proxmox
 ├── K8S-Master01
 ├── K8S-Worker01
 ├── K8S-Worker02
 └── K8S-Worker03
```

Benefits:

- Cleaner host management
- Easier upgrades
- Better isolation
- Improved recovery

---

# 11. High Availability (Optional)

Recommended for production workloads.

Typical minimum:

```text
3 Proxmox Nodes
```

With:

```text
Shared Storage
```

or

```text
Ceph
```

Capabilities:

- Automatic failover
- Live migration
- Planned maintenance without downtime

---

# 12. Disaster Recovery Planning

Design for failure.

## Disk Failure

Mitigation:

- RAID
- ZFS redundancy

## Host Failure

Mitigation:

- HA clusters
- Live migration

## Rack Failure

Mitigation:

- Replication
- Multiple racks

## Datacenter Failure

Mitigation:

- Offsite backups
- Secondary site
- Disaster recovery procedures

---

# Example SMB Architecture

```text
Datacenter
│
├── Proxmox Host
│   ├── ZFS RAID1 OS
│   ├── ZFS VM Pool
│   ├── VLAN Trunk
│   └── PBS Backup Network
│
├── VM: Domain Controller
├── VM: File Server
├── VM: SQL Server
├── VM: Application Server
├── VM: Docker Host
│
├── LXC: DNS
├── LXC: Monitoring
└── LXC: Reverse Proxy
```

---

# Key Design Decisions

The most important decisions in a Proxmox environment are:

1. Storage architecture
2. Network and VLAN design
3. Backup and recovery strategy
4. Security model
5. VM vs LXC deployment strategy
6. High availability requirements
7. Monitoring and observability

When these foundations are designed correctly, deploying and operating workloads on Proxmox becomes straightforward, scalable, and maintainable.
