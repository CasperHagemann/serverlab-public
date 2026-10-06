# serverlab

Scripts and documentation for configuring a bare-metal Proxmox VE node
with Proxmox's own tooling (bash, `pvesh`, `pvesm`).

## Scope

The Proxmox node itself: base system, networking, storage, resource
management, security, backup, monitoring and clustering. Guests (VMs,
containers, workloads) are out of scope and belong in a separate project.

## Where to start

| To                                              | Read                                             |
| ----------------------------------------------- | ------------------------------------------------ |
| See how an area is designed and what is planned | [`docs/design/`](docs/design/)                   |
| Understand why a choice was made                | [`docs/decisions/`](docs/decisions/)             |
| Set up the machine you work from                | [`docs/control-node.md`](docs/control-node.md)   |
| Run or write a script                           | [`scripts/README.md`](scripts/README.md)         |
| Find the values of a node                       | [`config/proxmox-nodes/`](config/proxmox-nodes/) |

The terms "control node" and "Proxmox node" are defined in
[ADR-0006](docs/decisions/0006-terminology-and-naming.md).

## Repository layout

| Path                                                  | Purpose                                                            |
| ----------------------------------------------------- | ------------------------------------------------------------------ |
| `config/`                                             | Node config read by the scripts, one `.env` file per node          |
| `docs/design/`                                        | One design doc per area: configuration, verification, planned work |
| `docs/decisions/`                                     | Architecture Decision Records                                      |
| `docs/runbooks/`                                      | Operational procedures                                             |
| `docs/control-node.md`                                | Control node setup                                                 |
| `inventory/`                                          | Hardware facts and the site network plan                           |
| `scripts/proxmox-node/`                               | One script per area, run on the Proxmox node                       |
| `scripts/control-node/`                               | Checks, formatters and git hooks, run on the control node          |
| `scripts/lib/`                                        | Shared bash libraries                                              |
| `scripts/remote-run.sh`                               | Runs the Proxmox-node scripts over one SSH connection              |
| `tests/`                                              | bats tests for the libraries                                       |
| `memory-bank/`, `.clinerules/`, `.cline/`, `.agents/` | Context and rules for AI assistants                                |
| `.vscode/`, `serverlab.code-workspace`                | Editor settings                                                    |

## License

See [`LICENSE`](LICENSE).
