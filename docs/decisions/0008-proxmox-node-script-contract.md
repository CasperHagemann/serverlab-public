# 0008. Proxmox-node script contract

Status: Accepted

Date: 2026-10-06

## Context

Scripts that change a Proxmox node must be safe to review, safe to re-run
and alike in behaviour. The first script (the VM bridge `vmbr1`) forced
these rules; the later ones follow them.

## Decision

One script per design area, `scripts/proxmox-node/<area>.sh`, named after
what the area configures, not its current feature. More features in an area
extend the script and its config keys. Scripts are independent and have no
run order. An area is split into `<area>-<detail>.sh` only when one script
becomes too large.

Every script has a `main` function that runs seven phases in order:

1. Parse arguments; read the config file, and prompt only for what is
   missing.
2. Pre-flight: check assumptions against real node state. If the target
   state already holds, log `Nothing to do.` as the last line and exit 0.
3. Plan: show the change, stop for `--dry-run`, and prompt unless `--yes`.
4. Back up and stage.
5. Apply.
6. Post-verify node state only. External reachability (for example pinging
   a gateway) is not checked: it can fail for reasons unrelated to the
   script. On failure, stop and report.
7. Summary.

Options: `--config <file>`, `--dry-run`, `--yes`, `-h`/`--help`. Exit
status is defined in [ADR-0005](0005-shell-coding-standards.md).

Rollback: on an apply or verify failure the script stops and prints the
manual undo commands (including the backup path). It never reverts
automatically.

Config keys: each area uses its own prefix (`BASE_`, `NET_`, `STORAGE_`,
`RESOURCE_`). A script reads and sets only its own keys and may read
another area's key, never set it.

Adding a new area:

1. Design doc in `docs/design/<area>.md` and a row in its index.
2. Script `scripts/proxmox-node/<area>.sh` with the seven phases.
3. Config keys with the area prefix in each node's `.env`
   ([ADR-0009](0009-node-configuration.md)).
4. bats tests for new library functions
   ([ADR-0007](0007-testing-and-quality-gates.md)).
5. A decision record if the choice is hard to reverse
   ([ADR-0011](0011-documentation-structure.md)).

## Consequences

- Scripts look the same, so a new one is mostly reuse of `lib/`.
- Stop-and-report keeps scripts simple but needs a person to run the printed
  undo step.
- Post-verify cannot catch a fault outside the node, such as a wrong switch
  configuration.
- Composing scripts across several nodes is out of scope
  ([ADR-0004](0004-use-bash-and-proxmox-native-tooling.md)).
