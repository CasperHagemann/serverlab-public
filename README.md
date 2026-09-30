# serverlab

A homelab project for standing up and configuring a Proxmox VE host from bare
metal, using native tooling.

## Status

**Phase 1 — single bare-metal host.** Proxmox VE is installed on
`pve.kiwik.org` (Minisforum MS-A2, see
[`inventory/hardware.md`](inventory/hardware.md)); host configuration is
being applied and documented.

## Roadmap

1. **Single host** (current) — configure the bare-metal host and finalize
   the major host design areas (see `docs/design/`).
2. **Clustering** — add a second physical machine, implement clustering and
   hardware-level failover (still homelab-scale, not enterprise HA).

Actual services (VMs, containers, workloads) are explicitly **out of scope**
for this repo — that will be a separate project once the host platform is
stable and trusted.

## Scope

This repo is concerned with the **Proxmox host only**: install, storage,
networking, security/access, backup, monitoring, and (eventually) clustering.
It is not concerned with guest provisioning or configuration.

Toolstack: bash scripting against the Proxmox CLI (`pvesh`, `qm`, `pct`,
`pvesm`) and/or the REST API. Rationale is recorded in the ADRs under
[`docs/decisions/`](docs/decisions/).

## Repository layout

| Path                      | Purpose                                                               |
| ------------------------- | --------------------------------------------------------------------- |
| `docs/design/`            | Design docs for each host design area (storage, networking, etc.)     |
| `docs/decisions/`         | Architecture Decision Records — point-in-time decisions and reasoning |
| `docs/runbooks/`          | Operational procedures                                                |
| `docs/inspiration/`       | Original unvetted reference material — not authoritative              |
| `docs/dev-environment.md` | Development environment / MCP server notes for contributors           |
| `inventory/`              | Source of truth for hardware, networks, and IP allocations            |
| `scripts/`                | Host configuration scripts (bash) and shared helpers                  |
| `.cline/mcp.json`         | MCP server config reference (manual copy-in, not auto-loaded)         |

## Contributing

Solo project for now. No `CONTRIBUTING.md` yet — conventions for scripts live
in [`scripts/README.md`](scripts/README.md).
