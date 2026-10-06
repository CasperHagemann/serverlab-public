# 0007. Testing and quality gates

Status: Accepted

Date: 2026-10-06

## Context

Code must be checked before it is committed, but the Proxmox node should
stay free of test tooling. Most script behaviour depends on real node state
and cannot be tested without the node. An automated Proxmox-node test runner
was tried earlier and removed: it was more code than the scripts it tested.

## Decision

- Checks run on the control node only, through
  `scripts/control-node/check.sh`: `shfmt`, `prettier`, `shellcheck`, the
  80-column limit, the ADR structure check, `ec` and, in fix mode, `bats`.
- A pre-commit hook runs `check.sh --check` on staged files. It changes
  nothing and does not run bats.
- Library functions with branching or parsing logic are tested with
  [bats-core](https://github.com/bats-core/bats-core) in `tests/lib/`, one
  file per library file. Tests source the library directly and replace
  Proxmox-only commands with stubs placed first on `PATH`. Thin wrappers
  around one command are not tested.
- Behaviour that depends on node state is checked by hand through
  `scripts/remote-run.sh`: dry-run, decline, `--yes` apply, then a no-op
  re-run. This is the final level of node verification; no automated node
  test runner is added. This covers script options too: `--help`, a bad
  option and a declined prompt (exit codes in
  [ADR-0005](0005-shell-coding-standards.md)) are tried by hand.

## Consequences

- The Proxmox node needs no extra packages.
- The manual walkthrough depends on someone running it after a change to a
  script or to `pve.sh` or `net.sh`; a regression can go unnoticed until then.
- Contributors need the tools listed in `docs/control-node.md`.
