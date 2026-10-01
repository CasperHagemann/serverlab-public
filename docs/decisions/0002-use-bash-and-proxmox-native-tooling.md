# 2. Use bash and Proxmox native tooling

Status: Accepted

Date: 2026-09-22

## Context

This repo configures a single Proxmox node (see root `README.md` for
scope: Proxmox node only, no guest/service provisioning). Configuration work is
currently done by a single administrator.

Common options for infrastructure/configuration tooling include Terraform,
Ansible, and plain shell scripting against native CLI/API tooling.

- **Terraform** is built around declarative resource lifecycle management
  against a provider API, backed by state files. Proxmox's own node
  configuration (network bridges, storage pools, node settings) doesn't map
  well onto that model — there's no multi-environment fleet of nodes to
  template, and introducing a state file adds operational overhead
  (locking, drift, backup of the state itself) for a single node.
- **Ansible** is well suited to configuring many similar nodes idempotently,
  or orchestrating multi-node changes. With one node and one admin, the
  overhead of inventories, playbooks, and roles isn't yet justified by the
  problem size.
- **Bash + `pvesh`** (Proxmox's REST API exposed locally) is directly
  supported on every Proxmox node with no extra tooling to install, matches
  the scope of the project (single-node, script-driven configuration), and
  keeps the same commands usable locally now and remotely later, since
  `pvesh` mirrors the REST API surface.

## Decision

We will write Proxmox-node configuration scripts in bash, using `pvesh` (falling
back to `qm`/`pct`/`pvesm` where `pvesh` is impractical) as the primary
interface to Proxmox, per the conventions in `scripts/README.md`. Terraform
is rejected for this project. Ansible is deferred, not rejected outright —
see below.

## Consequences

- No state file to manage, back up, or reconcile; correctness instead
  depends on scripts being idempotent (see `scripts/README.md`
  conventions).
- Scripts are simple to read and run manually on the Proxmox node, with no extra
  tooling to install.
- Cross-node orchestration (e.g. applying the same change to several nodes
  at once) has no built-in support and would need to be added manually if it
  becomes necessary.
- This decision is scoped to the _current_ single-node, single-admin
  reality. It should be revisited (a new ADR written) if any of the
  following change materially:
  - **Node count** grows beyond a small cluster (phase 2), where repeated
    manual application of scripts across nodes becomes error-prone enough
    that Ansible's idempotent, multi-node model pays for its overhead.
  - **Guest/service provisioning** enters scope (explicitly out of scope
    today — see root `README.md`), where Ansible's role/inventory model is
    a much stronger fit than ad hoc bash.
  - **A second administrator** joins the project, where shared, declarative
    tooling reduces the risk of undocumented manual steps or drift between
    people.
