# System Patterns

## Repository structure

```text
docs/
  decisions/           ADRs (README.md index, 0001-0013)
  design/              one doc per design area + README.md
  runbooks/            operational procedures
  control-node.md      contributor setup, MCP notes, VS Code shell fix
inventory/             hardware.md, ip-plan.md
config/                per-node config (config/proxmox-nodes/<hostname>.env)
scripts/
  control-node/        tooling that runs on the control node
    check.sh           formatting/lint/test entry point
    install-hooks.sh   one-time per-clone setup (core.hooksPath)
  lib/                 shared helpers by topic; loaded via common.sh
  proxmox-node/        scripts that run on the Proxmox node
                       (base-system.sh, networking.sh, storage.sh, resource-management.sh)
  remote-run.sh        run proxmox-node stages (or all) on the Proxmox node over one SSH connection
tests/                 bats-core suite for scripts/lib/*.sh
.githooks/pre-commit   calls check.sh --check
memory-bank/           this Memory Bank
.clinerules/           instructions/ (copied from GitHub awesome-copilot),
                       rules/ (copied from Cline's reference repo),
                       custom/ (written for this project; the only
                       folder edited by hand)
.agents/               upstream-synced; never edit or reformat
```

## Design doc structure

Each `docs/design/` doc: Scope, Configuration (what is live, or "None."),
Constraints, Implementation, Verification, Decision records, then a
separate **Planned** section (table: Item, Description, Depends on) for
anything not implemented.

## Key decisions

| Decision                                   | Record                                                                        |
| ------------------------------------------ | ----------------------------------------------------------------------------- |
| Bash + Proxmox-native tooling              | [ADR-0004](../docs/decisions/0004-use-bash-and-proxmox-native-tooling.md)     |
| Repository layout and sources of truth     | [ADR-0003](../docs/decisions/0003-repository-layout-and-sources-of-truth.md)  |
| Shell coding standards (Google guide)      | [ADR-0005](../docs/decisions/0005-shell-coding-standards.md)                  |
| Shared library design                      | [ADR-0006](../docs/decisions/0006-shared-library-design.md)                   |
| Testing and quality gates                  | [ADR-0007](../docs/decisions/0007-testing-and-quality-gates.md)               |
| Proxmox-node script contract               | [ADR-0008](../docs/decisions/0008-proxmox-node-script-contract.md)            |
| Node configuration                         | [ADR-0009](../docs/decisions/0009-node-configuration.md)                      |
| Remote execution                           | [ADR-0010](../docs/decisions/0010-remote-execution.md)                        |
| Documentation structure                    | [ADR-0011](../docs/decisions/0011-documentation-structure.md)                 |
| btrfs `local-data` for local guest storage | [ADR-0012](../docs/decisions/0012-local-guest-storage-btrfs.md)               |
| Terminology and naming                     | [ADR-0002](../docs/decisions/0002-terminology-and-naming.md)                  |
| Node resource priority                     | [ADR-0013](../docs/decisions/0013-node-resource-priority-and-fair-sharing.md) |

## Terminology

Defined in [ADR-0002](../docs/decisions/0002-terminology-and-naming.md): the
**control node** and the **Proxmox node**. Use these terms uniformly.

## Patterns

- **No extra packages on Proxmox nodes.** `scripts/lib/net.sh` reads
  `/sys/class/net` + `ip`/`awk` instead of `ip -j` + `jq`. `remote-run.sh`
  runs in the control node and may use richer tooling.
- **Proxmox-node scripts:** `<area>.sh` naming; idempotent; 7 phases; on failure
  stop and report manual undo steps, never roll back automatically.
- **Non-mutating pre-commit hook.** `check.sh --check` uses diff/check modes
  only, on staged files only; committed content equals reviewed content.
- **`.clinerules/` and `.agents/`** are excluded from `prettier`
  (`.prettierignore`) and `ec` (inline `-exclude` in `check.sh`).
- **Squash-merge only.** Default squash message is the PR title.

## check.sh

- **Fix mode** (default): whole repo, formats in place, then runs bats.
- **Check mode** (`--check`): staged files only, non-mutating, no bats.
- The tools and their order are listed in the header of `check.sh`.
- `trap on_failure ERR` (with `set -o errtrace`) prints the failing tool's
  output, then an `[ERROR]` block: how to fix (`./scripts/control-node/check.sh`) and how
  to bypass (`git commit --no-verify`).
- Tool availability is checked up front with `command -v`.
