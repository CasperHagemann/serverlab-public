# Architecture Decision Records

This directory records point-in-time decisions and the reasoning behind them,
for the Proxmox node configuration project. Unlike `docs/design/`, ADRs are
**not** updated as understanding evolves — if a decision changes, a new ADR
supersedes the old one, and the old one is kept for history.

## Index

| ADR                                                           | Title                                         | Status   |
| ------------------------------------------------------------- | --------------------------------------------- | -------- |
| [0001](0001-record-architecture-decisions.md)                 | Record architecture decisions                 | Accepted |
| [0002](0002-use-bash-and-proxmox-native-tooling.md)           | Use bash and Proxmox native tooling           | Accepted |
| [0003](0003-proxmox-node-script-structure-and-conventions.md) | Proxmox-node script structure and conventions | Accepted |
| [0004](0004-local-guest-storage-btrfs.md)                     | Local guest storage: btrfs                    | Accepted |

## Creating a new ADR

Copy [`template.md`](template.md) to `NNNN-short-title.md` (next sequential
number), fill it in, and add a row to the index above.
