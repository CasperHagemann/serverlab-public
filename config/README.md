# Config

Per-host configuration files read by `scripts/host/*.sh`, so the same
script works unchanged across hosts — see
[`../scripts/README.md`](../scripts/README.md).

## Layout

```text
config/
  hosts/
    <hostname>.env   one file per Proxmox host, named after its hostname
```

Scripts default to `config/hosts/$(hostname -f).env` and accept
`--config <file>` to override.

## Format

Plain `KEY=value` lines and `#` comments only — no command substitution,
variable expansion, or control flow. `config::load` (in
[`../scripts/lib/config.sh`](../scripts/lib/config.sh)) rejects anything
else before sourcing the file.

## Secrets

Never put passwords, API tokens, or certificates in these files. This
directory is always committed — everything here is treated as ordinary,
non-sensitive infrastructure data (see root `.gitignore` for the few things
that are excluded, e.g. `*.secret`).

## Relationship to `inventory/`

`inventory/` is the human-readable source of truth; these files are what
scripts actually read. The values must match — update both together when
something changes.
