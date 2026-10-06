# Scripts

Bash scripts for this repo: Proxmox-node configuration scripts
(`proxmox-node/`: install/post-install setup, storage, networking, security,
backup, monitoring), shared libraries (`lib/`), and control-node tooling
(`control-node/`, `remote-run.sh`). Guest/VM/container provisioning is
explicitly out of scope (see root README). The terms _control node_ and
_Proxmox node_ are defined in the root README (Environments).

## Conventions

### All scripts (control node and Proxmox node)

1. **`set -euo pipefail` at the top of every script.**
   - `-e`: stop on any command failure, rather than continuing in a
     half-configured state.
   - `-u`: stop on use of an unset variable (catches typos early).
   - `-o pipefail`: a pipeline fails if any command in it fails, not just the
     last one.

2. **shellcheck-clean.** Run `shellcheck path/to/script.sh` before
   considering a script done, and fix what it flags (in particular, quote
   all variable expansions: `"$VAR"` not `$VAR`). `./scripts/control-node/check.sh` runs
   this across all scripts at once.

3. **Formatted with `shfmt`.** Run `shfmt -w path/to/script.sh` before
   committing. Formatting rules (tabs, 4-space tab width, etc.) are defined
   in the repo's [`.editorconfig`](../.editorconfig), which `shfmt` reads
   automatically — no extra flags needed. To check formatting without
   changing anything (e.g. before committing), use `shfmt -d
path/to/script.sh`; a clean exit code (`0`) with no diff means the file
   is already formatted correctly. `./scripts/control-node/check.sh` runs this across all
   scripts at once, alongside the repo's other formatting/linting tools —
   see [`docs/control-node.md`](../docs/control-node.md).

4. **Follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)**
   for anything not already covered by shfmt/shellcheck (naming, quoting,
   `local`, function structure, 80-column lines). It's the de facto bash
   standard and the reference point for the conventions below.
   `./scripts/control-node/check.sh` enforces the line limit.

### Proxmox-node scripts (`scripts/proxmox-node/`)

These run on the Proxmox node and also follow:

5. **Idempotent where possible.** Scripts on a Proxmox node may be re-run —
   check whether a resource/state already exists before creating/changing
   it, rather than assuming a clean slate.

6. **No hardcoded node-specific values.** NIC names, disk device paths,
   VLAN IDs, etc. differ per node. Source these from a config file (see
   below) rather than hardcoding them, so the same script works unchanged
   across nodes.

7. **Prefer `pvesh` over memorizing individual CLI tool flags** (`qm`,
   `pct`, `pvesm`) where practical — `pvesh` exposes the full REST API
   locally and is a closer match to the API surface if scripts are later
   invoked remotely.

8. **No extra packages on Proxmox nodes unless absolutely necessary.**
   Scripts must work using only what's on a base Proxmox VE install (bash,
   `ip`, `awk`, `pvesh`, `ifupdown2`, etc.) — don't add a dependency like
   `jq` just for convenience. If richer processing is genuinely needed,
   do it on the control node (e.g. in `remote-run.sh`,
   which runs on the control node) instead of
   installing a package on every Proxmox node.

## `scripts/lib/` — shared function libraries

Shared code lives in `scripts/lib/`, split by topic into one file per
concern (`log.sh`, `guards.sh`, `prompt.sh`, `files.sh`, `config.sh`,
`pve.sh`, `net.sh`, `disk.sh`), loaded via a single `common.sh` that only
sources them:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
```

Rules for files in `lib/`:

- **Functions only.** Sourcing a `lib/` file must never run anything,
  change anything, or depend on the current environment — it just defines
  functions. Values (NIC names, IPs, etc.) come from config files or
  script arguments, never from `lib/`.
- **One topic per file**, named after that topic (e.g. all pvesh wrappers
  in `pve.sh`). Split a file once it starts covering more than one topic —
  there's no fixed line-count rule.
- **`pkg::function` naming** (e.g. `net::iface_exists`, `log::info`),
  matching the style guide's convention for library functions. The prefix
  tells you which file a function lives in.
- **Include guard** at the top of every file, so sourcing it twice is
  harmless:
  ```bash
  [[ -n "${SERVERLAB_LIB_FOO:-}" ]] && return 0
  readonly SERVERLAB_LIB_FOO=1
  ```
- **`local` for every variable declared inside a function** — otherwise
  bash variables are global by default and can leak between functions.
- **A header comment above every function**: purpose, arguments, and what
  it prints/returns (see any file in `lib/` for the expected format).

## Script structure

Beyond a trivial one-liner, a Proxmox-node script has a `main` function that
calls the others in order, with the script's last line being `main "$@"`.
Constants (e.g. file paths) are declared `readonly` near the top. The
phases, in order:

1. **Parse arguments / input.** Read required values from a config file
   first (see below), and only prompt interactively for anything missing —
   this keeps re-running scripts fast while still supporting first-run
   interactive setup. Support `--dry-run` and `--yes` where applicable.
2. **Pre-flight checks.** Read current Proxmox node state and verify assumptions —
   does the resource already exist, is a prerequisite file/interface
   present, is there a conflicting change already staged. If the target
   state already matches, log it and exit 0 (idempotency) rather than
   re-applying.
3. **Plan, diff, confirm.** Show what would change (e.g. a staged-config
   diff) before doing it. Honor `--dry-run` by stopping here. Otherwise
   prompt for confirmation, unless `--yes` was passed.
4. **Back up and stage.** Back up anything about to be overwritten before
   changing it.
5. **Apply.** Make the change.
6. **Post-verify.** Re-check Proxmox node state to confirm the change is
   correct (don't rely on external services responding, e.g. pinging a
   gateway — that can fail for reasons unrelated to the script and would
   trigger a false failure). On failure, stop and print the manual undo
   steps; scripts never roll back automatically.
7. **Summary.** Report what changed, where any backup lives, and whether a
   reboot is required.

See [`proxmox-node/networking.sh`](proxmox-node/networking.sh) and
[`proxmox-node/storage.sh`](proxmox-node/storage.sh) for concrete examples, and
[`docs/decisions/0003-proxmox-node-script-structure-and-conventions.md`](../docs/decisions/0003-proxmox-node-script-structure-and-conventions.md)
for the reasoning behind this structure.

## Configuration pattern

Scripts read required values (management interface name, VLAN IDs, etc.)
from a per-node config file in `config/proxmox-nodes/<hostname>.env`, and only
prompt interactively for values that are missing — see
[`config/README.md`](../config/README.md) for the file format and
`config::load`/`config::require` in
[`lib/config.sh`](lib/config.sh) for how scripts consume it.

## Running scripts on the remote Proxmox node

These scripts are meant to run **on** the Proxmox node (they call `pvesh`,
read `/etc/network/interfaces`, etc.), but this repo isn't necessarily
cloned there. Use [`remote-run.sh`](remote-run.sh) to run one or more
Proxmox-node scripts (or `all`) over a single SSH connection without copying
anything to the Proxmox node's filesystem first — see
[`docs/control-node.md`](../docs/control-node.md#running-scripts-on-the-remote-proxmox-node)
for usage and caveats.

## Layout

| Path            | Purpose                                                                                         |
| --------------- | ----------------------------------------------------------------------------------------------- |
| `lib/`          | Shared function libraries: logging, guards, prompts, file/config/pvesh/net helpers              |
| `proxmox-node/` | Post-install Proxmox-node configuration scripts, one per design area, independent of each other |
| `control-node/` | Control-node tooling: `check.sh` (format/lint/test), `install-hooks.sh` (git hooks setup)       |
| `remote-run.sh` | Runs on the control node; bundles and runs `proxmox-node/` stages on a Proxmox node             |
