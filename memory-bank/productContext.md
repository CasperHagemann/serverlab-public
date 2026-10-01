# Product Context

## Why this project exists

A personal homelab Proxmox node needs a documented, repeatable, and
reviewable way to go from bare metal to a running hypervisor platform,
without infrastructure-as-code tooling that is oversized for a single node
and a single administrator (see ADR-0002).

## Problems it solves

- **Lost decisions.** ADRs, design docs, and inventory record decisions and
  their reasoning.
- **Config drift and undocumented manual steps.** Checked-in bash scripts
  against Proxmox's native CLI/API are the source of truth for Proxmox-node
  configuration.
- **Inconsistent code quality.** A shared toolchain (`shfmt`, `prettier`,
  `shellcheck`, `editorconfig-checker`, `bats`) and a pre-commit hook keep
  scripts and docs consistent.

## How it works

- Architecturally significant decisions are recorded as ADRs
  (`docs/decisions/`), including rejected alternatives.
- Proxmox-node configuration is done with idempotent bash scripts (`scripts/README.md`).
- Every commit passes `scripts/control-node/check.sh --check` via the pre-commit hook
  (non-mutating).
- Work happens on feature branches, squash-merged into `main` via GitHub PRs.

## Audience

The administrator and the AI agent resuming across sessions. Documentation
must allow resuming without reconstructing context.
