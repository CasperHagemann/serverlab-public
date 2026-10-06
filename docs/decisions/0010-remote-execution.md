# 0010. Remote execution

Status: Accepted

Date: 2026-10-06

## Context

The Proxmox node may be reachable only over SSH and has no clone of this
repo. Stages still need prompts, and a network change can drop the
connection.

## Decision

`scripts/remote-run.sh <user@host> <stage>... | all [-- <stage-args>...]`
runs on the control node. It bundles `scripts/lib/*.sh` (without
`common.sh`), the requested stages and all node config files into one
compressed command, sent over one `ssh -t` call. The node picks the config
file matching its own `hostname -f`.

- Each stage runs in its own subshell; the run stops at the first stage
  that exits non-zero and reports finished, stopped and skipped stages.
- Stages never reboot the node. They call `log::reboot_required`, which
  records a reminder in `/run/serverlab/reboot-required`; the run ends with
  a summary of it.
- Nothing is written to the node by the bundling itself.
- A copy-then-run fallback (`tar` over SSH) stays documented for debugging,
  because it keeps real file and line numbers in errors.

## Consequences

- No clone, no persistent copy and no drift between what runs and the
  working tree.
- The full bundle is sent on every run, at the cost of some SSH traffic.
- Line numbers in errors refer to the bundle, not the files.
- Stage options and exit status are those of
  [ADR-0008](0008-proxmox-node-script-contract.md).
