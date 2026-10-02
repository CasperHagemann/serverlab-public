# Project Brief

## What this is

`serverlab` — a homelab project for standing up and configuring a single
Proxmox node from bare metal, using native tooling.

## Scope

**Proxmox node only.** Install, storage, networking, security/access, backup,
monitoring, and (eventually) clustering of the Proxmox node itself.

**Out of scope:** guest/VM provisioning and configuration, and any services
or workloads. That will be a separate project.

## Toolstack

Bash scripting against the Proxmox CLI (`pvesh`, `qm`, `pct`, `pvesm`)
and/or the REST API. Rationale:
[ADR-0002](../docs/decisions/0002-use-bash-and-proxmox-native-tooling.md).

## Roadmap

1. **single-node** (current phase) — configure `pve.kiwik.org` (Minisforum
   MS-A2) and complete the Proxmox-node design areas in `docs/design/`.
2. **Clustering** — second physical machine, clustering, hardware-level
   failover (homelab scale).

## Team

Single administrator (Casper Hagemann), working with an AI coding agent
(Cline).
