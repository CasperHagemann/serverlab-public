# Config

Per-node configuration files read by the scripts in
[`scripts/proxmox-node/`](../scripts/proxmox-node/), so the same script works
unchanged on every Proxmox node. How scripts use them:
[`scripts/README.md`](../scripts/README.md#configuration-pattern).

## Layout

```text
config/
  proxmox-nodes/
    <hostname>.env   one file per Proxmox node, named after its hostname
```

Scripts default to `config/proxmox-nodes/$(hostname -f).env` and accept
`--config <file>` to override.

## Format

Plain `KEY=value` lines, single-line arrays of quoted plain words
(`KEY=("a.example" "b.example")`, `KEY=()` for empty), and `#` comments only —
no command substitution, variable expansion, or control flow. `config::load` (in
[`../scripts/lib/config.sh`](../scripts/lib/config.sh)) rejects anything
else before sourcing the file.

## Keys

All keys a script reads must be set. An empty value has a defined meaning, and
a missing key stops the script. Each key is described, with its values and what
they do, in the design doc of its area:

| Area                | Design doc                                                        |
| ------------------- | ----------------------------------------------------------------- |
| Base system         | [`base-system.md`](../docs/design/base-system.md)                 |
| Networking          | [`networking.md`](../docs/design/networking.md)                   |
| Storage             | [`storage.md`](../docs/design/storage.md)                         |
| Resource management | [`resource-management.md`](../docs/design/resource-management.md) |

## Secrets

Never put passwords, API tokens, or certificates in these files. This
directory is always committed — everything here is treated as ordinary,
non-sensitive infrastructure data (see root `.gitignore` for the few things
that are excluded, e.g. `*.secret`).

## Relationship to `inventory/`

`config/` holds the values a script applies. [`inventory/`](../inventory/)
holds the facts no script sets: the hardware and the site network plan. A value
lives in one of them, not both.
