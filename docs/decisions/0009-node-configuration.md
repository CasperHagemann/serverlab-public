# 0009. Node configuration

Status: Accepted

Date: 2026-10-06

## Context

The same script must work unchanged on every Proxmox node, but NIC names,
disks and addresses differ per node. Sourcing a file as shell code is
convenient but would run anything written in it.

## Decision

Each Proxmox node has `config/proxmox-nodes/<hostname>.env`, always
committed and never holding secrets. It contains only `KEY=value` lines,
single-line arrays of quoted plain words and `#` comments. `config::load`
rejects anything else before sourcing the file.

Keys are `UPPER_CASE` with an area prefix (see
[ADR-0008](0008-proxmox-node-script-contract.md)). A script requires every
key it reads; an empty value has a defined meaning, a missing key stops the
script. Scripts default to the file named after `hostname -f` and accept
`--config <file>`.

Each key is documented in the design doc of its area, with an example value
and the effect of each value.

## Consequences

- One script serves all nodes; a new node needs only a new file.
- Values that also appear in `inventory/` must be kept consistent by hand
  ([ADR-0003](0003-repository-layout-and-sources-of-truth.md) says a value
  lives in one place, so `inventory/` holds facts no script sets).
- Renaming a key means changing the `.env`, the script, tests and the design
  doc together.
