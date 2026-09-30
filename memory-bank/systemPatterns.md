# System Patterns

## Repository structure

```text
docs/
  decisions/           ADRs (template.md, README.md index, 0001-0004)
  design/              00-overview.md .. 08-high-availability.md + README.md
  runbooks/            operational procedures
  inspiration/         unvetted reference material
  dev-environment.md   contributor setup, MCP notes, VS Code shell fix
inventory/             hardware.md, networks.md, ip-plan.md
config/                per-host config (config/hosts/<hostname>.env)
scripts/
  check.sh             formatting/lint/test entry point
  install-hooks.sh     one-time per-clone setup (core.hooksPath)
  lib/                 shared helpers by topic (log, guards, prompt, files,
                       config, pve, net, disk); loaded via common.sh
  host/                host scripts (10-network.sh, 20-storage.sh)
  remote-run.sh        run a host script on the Proxmox host over SSH
tests/                 bats-core suite for scripts/lib/*.sh
.githooks/pre-commit   calls check.sh --check
memory-bank/           this Memory Bank
.clinerules/, .agents/ upstream-synced; never edit or reformat
```

## Design doc structure

Each `docs/design/` doc: Scope, Configuration (what is live, or "None."),
Constraints, Implementation, Verification, Decision records, then a
separate **Planned** section (table: Item, Description, Depends on) for
anything not implemented.

## Key decisions

| Decision                                   | Record                                                                      |
| ------------------------------------------ | --------------------------------------------------------------------------- |
| Bash + Proxmox-native tooling              | [ADR-0002](../docs/decisions/0002-use-bash-and-proxmox-native-tooling.md)   |
| Host script structure and conventions      | [ADR-0003](../docs/decisions/0003-host-script-structure-and-conventions.md) |
| btrfs `local-data` for local guest storage | [ADR-0004](../docs/decisions/0004-local-guest-storage-btrfs.md)             |

## Patterns

- **No extra packages on Proxmox hosts.** `scripts/lib/net.sh` reads
  `/sys/class/net` + `ip`/`awk` instead of `ip -j` + `jq`. `remote-run.sh`
  runs in the development environment and may use richer tooling.
- **Host scripts:** `NN-<area>.sh` naming; idempotent; 7 phases; on failure
  stop and report manual undo steps, never roll back automatically.
- **Non-mutating pre-commit hook.** `check.sh --check` uses diff/check modes
  only, on staged files only; committed content equals reviewed content.
- **`.clinerules/` and `.agents/`** are excluded from `prettier`
  (`.prettierignore`) and `ec` (inline `-exclude` in `check.sh`).
- **Squash-merge only.** Default squash message is the PR title.

## check.sh

- **Fix mode** (default): whole repo. `shfmt -w` → `prettier --write` →
  `shellcheck -S warning` → `ec -exclude '<pattern>'` → bats.
- **Check mode** (`--check`): staged files only, non-mutating. `shfmt -d` →
  `shellcheck -S warning` → `prettier --check` → `ec`. No bats.
- `trap on_failure ERR` (with `set -o errtrace`) prints the failing tool's
  output, then an `[ERROR]` block: how to fix (`./scripts/check.sh`) and how
  to bypass (`git commit --no-verify`).
- Tool availability is checked up front with `command -v`.
