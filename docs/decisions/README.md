# Architecture Decision Records

Design decisions currently in force for this project, and the reasoning
behind them. Detailed target state lives in
`docs/design/`. See [ADR-0001](0001-record-architecture-decisions.md).

## Index

| ADR                                                           | Title                                         | Status   |
| ------------------------------------------------------------- | --------------------------------------------- | -------- |
| [0001](0001-record-architecture-decisions.md)                 | Record architecture decisions                 | Accepted |
| [0002](0002-use-bash-and-proxmox-native-tooling.md)           | Use bash and Proxmox native tooling           | Accepted |
| [0003](0003-proxmox-node-script-structure-and-conventions.md) | Proxmox-node script structure and conventions | Accepted |
| [0004](0004-local-guest-storage-btrfs.md)                     | Local guest storage: btrfs                    | Accepted |
| [0005](0005-node-resource-priority-and-fair-sharing.md)       | Node resource priority and fair sharing       | Accepted |
| [0006](0006-terminology-and-naming.md)                        | Terminology and naming                        | Accepted |

## Creating or changing an ADR

ADRs describe the decisions currently in force. When a decision changes,
update its ADR in place and its date; git history keeps earlier versions.
Remove an ADR whose decision no longer applies, and remove its row from the
index.

Structure, required content and workflow:
[`.clinerules/custom/adr-decisions.md`](../../.clinerules/custom/adr-decisions.md).
The structure is checked by `scripts/control-node/check.sh`.
