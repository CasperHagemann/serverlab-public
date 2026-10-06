# Control Node

This document explains the control-node setup for contributors to this
repo, including MCP (Model Context Protocol) server usage with Cline.

## MCP servers

Cline does not currently support workspace-scoped MCP server configuration —
MCP servers must be added manually in each contributor's own IDE/Cline
settings. [`.cline/mcp.json`](../.cline/mcp.json) in this repo is **not**
read automatically by Cline; it exists purely as:

1. A copy-paste-able reference for which MCP servers this project expects
   contributors to have configured.
2. A record of which servers have been set up.

To use it: open `.cline/mcp.json`, and manually add the relevant server
entries into your own Cline MCP settings.

## Current servers

| Server                | Command                                                   | Purpose                                                        | Notes                                                                                                                                                                    |
| --------------------- | --------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fetch`               | `uvx mcp-server-fetch`                                    | Fetch and read live web pages (e.g. Proxmox VE docs) in chunks | Requires `uv`/`uvx` (`sudo pacman -S uv`). Obeys `robots.txt` by default. Can reach internal/private IPs — treat as a caveat, not a blocker, on a host-only lab network. |
| `sequential-thinking` | `npx -y @modelcontextprotocol/server-sequential-thinking` | Step-by-step reasoning for multi-step planning/analysis        | Requires Node/`npx` (`sudo pacman -S nodejs npm`). No network or file access beyond the package download.                                                                |

Solves a real limitation of the IDE's built-in fetch tool: it silently
truncates long pages (observed losing the Two-Factor Authentication section
of the PVE `pveum` docs at ~35k characters). The `fetch` MCP server instead
returns an explicit `start_index` continuation marker when a page is
truncated, so the rest of the page can be paged through deliberately.

Versions are intentionally **not pinned** for either server (this is a
homelab, not a production/enterprise setup, so the lower-maintenance
tradeoff is preferred). `uvx`/`npx` may keep reusing an already-downloaded
copy rather than fetching a newer one; clear the relevant cache (`uv cache
clean`, `npm cache clean --force`) if you want to force a refresh.

See `.cline/mcp.json` for the current server configuration.

## Required CLI tools

Install on Arch-based distros (e.g. CachyOS):

```bash
sudo pacman -S shfmt shellcheck editorconfig-checker prettier bats
```

| Tool         | Package                | Handles                                                         | Fixes automatically? |
| ------------ | ---------------------- | --------------------------------------------------------------- | -------------------- |
| `shfmt`      | `shfmt`                | `.sh` formatting                                                | yes                  |
| `prettier`   | `prettier`             | `.json`/`.md` formatting                                        | yes                  |
| `shellcheck` | `shellcheck`           | `.sh` correctness (bugs, not style)                             | no — reports only    |
| `ec`         | `editorconfig-checker` | verifies everything against [`.editorconfig`](../.editorconfig) | no — reports only    |
| `bats`       | `bats`                 | runs `tests/*.bats` (`scripts/lib/` unit tests)                 | no — reports only    |

`shfmt` and `prettier` are formatters: they rewrite files to match
[`.editorconfig`](../.editorconfig)'s rules (tabs/4-space for `.sh`,
2-space for `.json`, etc.), and never change what the code does.
`shellcheck` is a linter: it never touches formatting and instead looks for
actual bugs (unquoted variables, unreachable code, etc.) — see
[`scripts/README.md`](../scripts/README.md) for the conventions it enforces.
`ec` is the verification step that confirms the repo is fully compliant with
`.editorconfig` after the formatters have run. `bats` runs the test suite
under [`tests/`](../tests/README.md) — control node only, never installed
on Proxmox nodes (see
[ADR-0003](decisions/0003-proxmox-node-script-structure-and-conventions.md)).

Run all five in one go before committing:

```bash
./scripts/control-node/check.sh
```

See [`scripts/control-node/check.sh`](../scripts/control-node/check.sh) for exactly what it runs.

## Pre-commit hook

`./scripts/control-node/check.sh` has a `--check` mode: the same four formatting/lint
tools (not `bats` — the test suite runs on the whole `tests/` tree
regardless of what's staged, and is slower, so it only runs in fix mode,
i.e. plain `./scripts/control-node/check.sh`), restricted to **staged files only**, and
never modifies anything (uses `shfmt -d` / `prettier --check` instead of the
writing equivalents). This is wired up as a git pre-commit hook so drift is
caught automatically.

One-time setup per clone (hooks live in `.githooks/`, which is tracked, but
`core.hooksPath` itself is a local git config that doesn't survive a
clone):

```bash
./scripts/control-node/install-hooks.sh
```

After that, every `git commit` runs `./scripts/control-node/check.sh --check` first. If
it fails, the commit is aborted with no files touched — run
`./scripts/control-node/check.sh` (no flag) to fix, re-stage, and commit again. To bypass
in an emergency: `git commit --no-verify`.

## VS Code: terminal shell integration (fish → bash)

**Symptom:** Cline's terminal commands appear to run instantly but return
garbled output (the command line echoed back) instead of real
stdout/exit codes, e.g. running `git status` returns something like:

```text
cd /path/to/repo && git status - cd\
```

**Cause:** Cline drives the integrated terminal through VS Code's shell
integration API, which injects a small script into the shell at startup so
it can capture real output. On this project this broke because the default
Linux shell was **fish** (CachyOS's default) — the injection/handshake
doesn't complete reliably under fish (and can also be affected by heavily
customized zsh prompts, e.g. Starship).

**Fix:** [`.vscode/settings.json`](../.vscode/settings.json) in this repo
sets the integrated terminal's default profile to `bash` and explicitly
enables shell integration:

```json
{
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.shellIntegration.enabled": true
}
```

This only affects the **VS Code integrated terminal** — your normal
interactive shell outside VS Code (e.g. fish in a regular terminal emulator)
is unaffected.

**Caveat — Workspace Trust:** `terminal.integrated.defaultProfile.linux` is a
machine-overridable setting and is **ignored while a workspace is open in
Restricted Mode**. If the terminal reverts to fish and Cline's commands stop
returning real output again, check Workspace Trust first (VS Code should
prompt to trust this folder on first open; accept it).

**If this still doesn't work for you:** confirm which shell your integrated
terminal is actually using (open a terminal, run `echo $0`), and check that
`.vscode/settings.json` is being picked up (it applies to plain
`code .`/Open Folder as well as opening `serverlab.code-workspace`).

## Running scripts on the remote Proxmox node

`scripts/proxmox-node/*.sh` are written to run **on** the Proxmox node — they call
`pvesh`, read `/etc/network/interfaces`, etc. If you don't have a clone of
this repo on the Proxmox node but can reach it over SSH, use
[`scripts/remote-run.sh`](../scripts/remote-run.sh) instead of copying
files over manually:

```bash
scripts/remote-run.sh root@192.168.88.101 networking.sh -- --dry-run
```

This bundles `scripts/lib/*.sh`, the target script, and (if present) the
matching `config/proxmox-nodes/<remote-hostname>.env` into a single command and
runs it over `ssh -t`, so interactive prompts still work and nothing is
written to the Proxmox node's filesystem by this step — only the target script's
own work (e.g. a config backup) touches the Proxmox node's disk. Re-run it after
every local change; the Proxmox node never keeps its own copy to drift out
of sync with your working tree.

**Caveat — dropped SSH sessions.** Applying a network change reloads
interfaces on the Proxmox node (`ifreload -a`), including the one your SSH session
is using. Scripts guard the apply and verify steps against `SIGHUP` so
a dropped session doesn't kill them partway through, but if your connection
does drop, reconnect and re-run the script — pre-flight checks are designed
to report "nothing to do" if the change already succeeded, or resume
cleanly if it didn't.

### Full deployment in one connection

A full setup (all stages, or a chosen list) needs one login and one input
from the administrator per run, whichever login method is used (see
[SSH login options](design/security-access.md#ssh-login-options)).

```bash
scripts/remote-run.sh root@192.168.88.101 all -- --dry-run
scripts/remote-run.sh root@192.168.88.101 all -- --yes
scripts/remote-run.sh root@192.168.88.101 networking.sh storage.sh
```

How it works: all stages go into one bundle, sent compressed with one
`ssh -t` call.

- Several script names, or `all` (every `[0-9][0-9]-*.sh` stage, in name
  order), go before `--`. The flags after `--` go to every stage. All names
  are checked before anything is sent.
- Every config file in `config/proxmox-nodes/` is in the bundle. The
  Proxmox node picks the one that matches its own `hostname -f`, so no
  second login is needed to find its name. If none matches, the run stops
  before the first stage.
- Each stage runs in its own subshell, so the `exit` at the end of a stage
  ends only that stage.
- The run stops at the first non-zero exit and reports which stages
  finished, which stopped and which were not run.
- Stages never reboot the node. A stage that needs a reboot applies its
  config, calls `log::reboot_required "<reason>"` and exits 0. The reason
  is shown at once, listed in the summary at the end of the run, and kept in
  `/run/serverlab/reboot-required`. `/run` is cleared on boot, so the
  reminder is shown again at the start and end of every run until the
  administrator reboots. This also covers a dropped session, where the
  summary is lost.

Rejected: sharing one SSH connection between calls (`ControlMaster`). If the
script is killed hard, the connection stays open for the `ControlPersist`
time and can be used without any input. This was tried on a branch and
dropped.

Constraints:

- A stage that changes the network (`networking.sh`, `ifreload -a`) can drop
  the session, so the stages after it do not run. Reconnect and re-run; the
  finished stages report "Nothing to do".
- A dry run of several stages shows what each stage would do on its own,
  not on a node that earlier stages have changed.

Two-stage option: if the deployment grows, run it in two calls. The first
holds the stages that can break the connection, the second the rest. Each
call needs one login.

Rules that keep this possible (see
[ADR-0003](decisions/0003-proxmox-node-script-structure-and-conventions.md)):

- A stage runs on its own and does not need another stage to have run.
- A stage never reboots the node. If a change needs a reboot, the stage
  applies its config, calls `log::reboot_required` and exits 0.
- All stages take the same flags: `--config`, `--dry-run` and `--yes`.
- A stage exits with 0 (done or nothing to do) or 1 (aborted or failed).

**Fallback — copy-then-run.** For debugging (e.g. so error line numbers
match the real files), you can instead copy the files to the Proxmox node and run
them there directly:

```bash
tar -czf - scripts config | ssh root@192.168.88.101 'mkdir -p /root/serverlab && tar -xzf - -C /root/serverlab'
ssh -t root@192.168.88.101 '/root/serverlab/scripts/proxmox-node/networking.sh --dry-run'
```

Treat this copy as a throwaway snapshot — re-run the `tar` step after any
local change rather than editing the copy on the Proxmox node.
