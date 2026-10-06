# 0006. Terminology and naming

Status: Accepted

Date: 2026-10-06

## Context

Two machines take part in this project, and docs, scripts and comments
refer to them constantly. Words such as "host", "server", "local" and
"remote" are ambiguous here: each can mean either machine, and "node" also
has a Proxmox API meaning. Without fixed terms the docs drift. File, key
and function names have the same problem if each author picks their own
casing and prefixes.

## Decision

Terms:

- **Control node**: the machine where this repo is cloned and worked on. It
  runs `scripts/control-node/`, `scripts/remote-run.sh`, the tests, the
  formatters and linters, and the git hooks. The term comes from Ansible.
- **Proxmox node**: the machine running Proxmox VE that is configured. It
  runs `scripts/proxmox-node/*.sh`. Ansible's "managed node" is replaced by
  Proxmox's own word.

The other words are not used for these two machines: "host", "server",
"workstation", "development environment", and an unqualified "local" or
"remote". "Node" on its own is used only in the Proxmox API and cluster
sense (`/nodes/<node>`, `pve::node`). "Hostname" stays, as the operating
system concept.

Names:

- Design docs and scripts are named after the area they cover, in lowercase
  with hyphens, with no number prefix: `docs/design/<area>.md` and
  `scripts/proxmox-node/<area>.sh`. ADRs are `NNNN-short-title.md`.
- Node config files are `config/proxmox-nodes/<hostname>.env`. Config keys
  are `UPPER_CASE` with underscores.
- Library functions are `pkg::function`, as in ADR-0003. Other shell
  style follows the Google Shell Style Guide, also adopted in ADR-0003.
- Markdown and shell formatting is set by Prettier, shfmt and
  `.editorconfig`, and checked by `scripts/control-node/check.sh`.

## Consequences

- A reader or an AI assistant can tell which machine a sentence is about.
- The terms are written once here. Other docs use them and link to this
  ADR instead of defining them again.
- Renaming an area means renaming its design doc, script and, where used,
  its config keys together.
- The ADR does not cover the content or structure of design docs, which is
  described in `docs/design/README.md`.
