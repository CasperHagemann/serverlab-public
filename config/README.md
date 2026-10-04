# Config

Per-node configuration files read by `scripts/proxmox-node/*.sh`, so the same
script works unchanged across nodes — see
[`../scripts/README.md`](../scripts/README.md).

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

## Post-install settings

Read by `scripts/proxmox-node/05-proxmox-install.sh`; all must be set (an
empty value has a defined meaning, a missing line stops the script). Values and
meanings: [`../docs/design/02-proxmox-install.md`](../docs/design/02-proxmox-install.md).

| Key               | Type   | Example               |
| ----------------- | ------ | --------------------- |
| `TIMEZONE`        | string | `"Europe/Copenhagen"` |
| `NTP_SERVERS`     | array  | `("0.pool.ntp.org")`  |
| `PVE_REPOSITORY`  | string | `"no-subscription"`   |
| `CEPH_REPOSITORY` | string | `"disabled"`          |

## Secrets

Never put passwords, API tokens, or certificates in these files. This
directory is always committed — everything here is treated as ordinary,
non-sensitive infrastructure data (see root `.gitignore` for the few things
that are excluded, e.g. `*.secret`).

## Relationship to `inventory/`

`inventory/` is the human-readable source of truth; these files are what
scripts actually read. The values must match — update both together when
something changes.
