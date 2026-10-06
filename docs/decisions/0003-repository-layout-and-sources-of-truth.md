# 0003. Repository layout and sources of truth

Status: Accepted

Date: 2026-10-06

## Context

The repo holds scripts, per-node values, hardware facts, design docs and
decisions. Without a rule for where each kind of fact lives, the same fact
is written in several places and the copies drift apart. The scripts also
run on two different machines (see [ADR-0002](0002-terminology-and-naming.md)),
so the layout must show which code runs where.

## Decision

Each kind of fact has one owner:

| Location                                         | Owns                                                             |
| ------------------------------------------------ | ---------------------------------------------------------------- |
| `config/proxmox-nodes/<hostname>.env`            | Every value specific to one Proxmox node                         |
| `inventory/`                                     | Hardware facts and the site network plan                         |
| `docs/design/`                                   | What is configured and how, per area                             |
| `docs/decisions/`                                | Decisions in force, with reasons and rejected options            |
| `docs/runbooks/`                                 | Step-by-step procedures                                          |
| `scripts/proxmox-node/`                          | One script per design area, run on the Proxmox node              |
| `scripts/lib/`                                   | Shared libraries (see [ADR-0006](0006-shared-library-design.md)) |
| `scripts/control-node/`, `scripts/remote-run.sh` | Tooling run on the control node                                  |
| `tests/`                                         | bats tests (see [ADR-0007](0007-testing-and-quality-gates.md))   |

A value lives in one place only. Other files name the config key or link to
the owner and do not repeat the value. No secrets are committed.

## Consequences

- A change to a value is one edit, in the owner.
- Docs that repeat a value of another file are a defect.
- Adding an area means adding its design doc, script and config keys
  together (see [ADR-0008](0008-proxmox-node-script-contract.md)).
