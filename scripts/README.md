# Scripts

Bash scripts for this repo:

- [`proxmox-node/`](proxmox-node/): one script per design area, run on the
  Proxmox node.
- [`lib/`](lib/): shared libraries.
- [`control-node/`](control-node/) and [`remote-run.sh`](remote-run.sh): tooling
  run on the control node.

The terms _control node_ and _Proxmox node_ are defined in
[ADR-0002](../docs/decisions/0002-terminology-and-naming.md). Guests are out
of scope.

## Conventions

The rules are decisions, kept in the ADRs:

- Style, formatting, `--help` and exit status:
  [ADR-0005](../docs/decisions/0005-shell-coding-standards.md).
- Shared libraries in `lib/`:
  [ADR-0006](../docs/decisions/0006-shared-library-design.md).
- Proxmox-node scripts (phases, options, rollback, adding an area):
  [ADR-0008](../docs/decisions/0008-proxmox-node-script-contract.md).

In practice:

```bash
shfmt -w path/to/script.sh        # format (reads .editorconfig)
shellcheck path/to/script.sh      # lint
./scripts/control-node/check.sh   # everything, repo-wide
```

Proxmox-node scripts use only what a base Proxmox VE install provides
(bash, `ip`, `awk`, `pvesh`, `ifupdown2`, ...). Do richer processing on thecontrol node, for example in `remote-run.sh`. Prefer `pvesh` over `qm`,
`pct` and `pvesm` where practical.

See [`proxmox-node/networking.sh`](proxmox-node/networking.sh) and
[`proxmox-node/storage.sh`](proxmox-node/storage.sh) for examples.

## Configuration pattern

Scripts read their values from the per-node config file
`config/proxmox-nodes/<hostname>.env`, and stop if a required value is missing.
The file format is described in [`config/README.md`](../config/README.md).
Scripts use `config::load` and `config::require` from
[`lib/config.sh`](lib/config.sh).

## Running scripts on the remote Proxmox node

These scripts are meant to run **on** the Proxmox node (they call `pvesh`,
read `/etc/network/interfaces`, etc.), but this repo isn't necessarily
cloned there. Use [`remote-run.sh`](remote-run.sh) ([ADR-0010](../docs/decisions/0010-remote-execution.md)) to run one or more
Proxmox-node scripts (or `all`) over a single SSH connection without copying
anything to the Proxmox node's filesystem first — see
[`docs/control-node.md`](../docs/control-node.md#running-scripts-on-the-remote-proxmox-node)
for usage and caveats.

## Layout

| Path            | Purpose                                                                                         |
| --------------- | ----------------------------------------------------------------------------------------------- |
| `lib/`          | Shared function libraries, one file per topic                                                   |
| `proxmox-node/` | Post-install Proxmox-node configuration scripts, one per design area, independent of each other |
| `control-node/` | Control-node tooling: `check.sh` (format/lint/test), `install-hooks.sh` (git hooks setup)       |
| `remote-run.sh` | Runs on the control node; bundles and runs `proxmox-node/` stages on a Proxmox node             |
