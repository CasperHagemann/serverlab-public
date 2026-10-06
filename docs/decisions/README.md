# Architecture Decision Records

Design decisions currently in force for this project, and the reasoning
behind them. Detailed target state lives in
`docs/design/`. See [ADR-0001](0001-record-architecture-decisions.md).

## Index

| ADR                                                     | Title                                   | Status   |
| ------------------------------------------------------- | --------------------------------------- | -------- |
| [0001](0001-record-architecture-decisions.md)           | Record architecture decisions           | Accepted |
| [0002](0002-terminology-and-naming.md)                  | Terminology and naming                  | Accepted |
| [0003](0003-repository-layout-and-sources-of-truth.md)  | Repository layout and sources of truth  | Accepted |
| [0004](0004-use-bash-and-proxmox-native-tooling.md)     | Use bash and Proxmox native tooling     | Accepted |
| [0005](0005-shell-coding-standards.md)                  | Shell coding standards                  | Accepted |
| [0006](0006-shared-library-design.md)                   | Shared library design                   | Accepted |
| [0007](0007-testing-and-quality-gates.md)               | Testing and quality gates               | Accepted |
| [0008](0008-proxmox-node-script-contract.md)            | Proxmox-node script contract            | Accepted |
| [0009](0009-node-configuration.md)                      | Node configuration                      | Accepted |
| [0010](0010-remote-execution.md)                        | Remote execution                        | Accepted |
| [0011](0011-documentation-structure.md)                 | Documentation structure                 | Accepted |
| [0012](0012-local-guest-storage-btrfs.md)               | Local guest storage: btrfs              | Accepted |
| [0013](0013-node-resource-priority-and-fair-sharing.md) | Node resource priority and fair sharing | Accepted |

## Creating or changing an ADR

ADRs describe the decisions currently in force. When a decision changes,
update its ADR in place and its date; git history keeps earlier versions.
Remove an ADR whose decision no longer applies, and remove its row from the
index.

Structure, required content and workflow:
[`.clinerules/custom/adr-decisions.md`](../../.clinerules/custom/adr-decisions.md).
The structure is checked by `scripts/control-node/check.sh`.
