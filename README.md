# serverlab

A homelab project for standing up and configuring a Proxmox node from bare
metal, using native tooling.

## Status

**Phase 1 — single bare-metal Proxmox node.** Proxmox VE is installed on
`pve.kiwik.org` (Minisforum MS-A2, see
[`inventory/hardware.md`](inventory/hardware.md)); Proxmox-node configuration is
being applied and documented.

## Roadmap

1. **Single node** (current) — configure the bare-metal Proxmox node and finalize
   the major Proxmox-node design areas (see `docs/design/`).
2. **Clustering** — add a second physical machine, implement clustering and
   hardware-level failover (still homelab-scale, not enterprise HA).

Actual services (VMs, containers, workloads) are explicitly **out of scope**
for this repo — that will be a separate project once the Proxmox node platform is
stable and trusted.

## Scope

This repo is concerned with the **Proxmox node only**: install, storage,
networking, security/access, backup, monitoring, and (eventually) clustering.
It is not concerned with guest provisioning or configuration.

Toolstack: bash scripting against the Proxmox CLI (`pvesh`, `qm`, `pct`,
`pvesm`) and/or the REST API. Rationale is recorded in the ADRs under
[`docs/decisions/`](docs/decisions/).

## Environments

Two machines are involved. The terms below are used uniformly across the
repo: **control node** comes from Ansible's vocabulary, and **Proxmox node**
replaces Ansible's "managed node" with Proxmox's own word for a server.

| Term             | Meaning                                              | What runs there                                                                                   |
| ---------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Control node** | The machine where this repo is cloned and worked on. | `scripts/control-node/*`, `scripts/remote-run.sh`, tests (`bats`), formatters/linters, git hooks. |
| **Proxmox node** | The server running Proxmox VE that is configured.    | `scripts/proxmox-node/*.sh` and the Proxmox tooling they call (`pvesh`, `pvesm`).                 |

Do not use "host", "server", "workstation", "development environment" or an
unqualified "local"/"remote" for these machines. "Node" on its own is only
used in the Proxmox API/cluster sense (`/nodes/<node>`, `pve::node`).
"Hostname" stays, since it is the operating-system concept.

## Repository layout

| Path                   | Purpose                                                                   |
| ---------------------- | ------------------------------------------------------------------------- |
| `docs/design/`         | Design docs for each Proxmox-node design area (storage, networking, etc.) |
| `docs/decisions/`      | Architecture Decision Records — point-in-time decisions and reasoning     |
| `docs/runbooks/`       | Operational procedures                                                    |
| `docs/inspiration/`    | Original unvetted reference material — not authoritative                  |
| `docs/control-node.md` | Control node setup and MCP server notes for contributors                  |
| `inventory/`           | Source of truth for hardware, networks, and IP allocations                |
| `scripts/`             | Configuration scripts (bash) and shared helpers                           |
| `.cline/mcp.json`      | MCP server config reference (manual copy-in, not auto-loaded)             |

## Contributing

Solo project for now. No `CONTRIBUTING.md` yet — conventions for scripts live
in [`scripts/README.md`](scripts/README.md).
