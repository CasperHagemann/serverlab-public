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

`shfmt` and `prettier` rewrite files to match
[`.editorconfig`](../.editorconfig) and never change what the code does.
`shellcheck` looks for bugs (unquoted variables, unreachable code), not
style. `ec` confirms the repo matches `.editorconfig` after the formatters
have run. `bats` runs the tests under [`tests/`](../tests/README.md). Why
these tools: [ADR-0007](decisions/0007-testing-and-quality-gates.md).

Run all five in one go before committing:

```bash
./scripts/control-node/check.sh
```

See [`scripts/control-node/check.sh`](../scripts/control-node/check.sh) for exactly what it runs.

## Pre-commit hook

A git pre-commit hook runs `./scripts/control-node/check.sh --check`: the
formatting and lint checks on staged files, without changing anything and
without the tests ([ADR-0007](decisions/0007-testing-and-quality-gates.md)).

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

`scripts/proxmox-node/*.sh` run **on** the Proxmox node. Without a clone of
this repo there, use [`scripts/remote-run.sh`](../scripts/remote-run.sh): it
sends the scripts and config over one `ssh -t` call, so prompts work and
nothing is left on the node. Why it works this way:
[ADR-0010](decisions/0010-remote-execution.md).

```bash
scripts/remote-run.sh root@192.168.88.101 all -- --dry-run
scripts/remote-run.sh root@192.168.88.101 all -- --yes
scripts/remote-run.sh root@192.168.88.101 networking.sh storage.sh
```

Stage names go before `--` (or `all` for every script in
`scripts/proxmox-node/`); the options after `--` go to every stage. All names
are checked before anything is sent. A full run needs one login (see
[SSH login options](design/security-access.md#ssh-login-options)).

- **Dropped session:** `networking.sh` reloads the interfaces, which can drop
  the SSH session. Reconnect and re-run the same command; finished stages
  report "Nothing to do".
- **Reboot reminder:** a stage that needs a reboot says so, and the reminder
  is shown at the start and end of every run until the node is rebooted.
- **Dry run:** each stage shows what it would do on its own, not on a node
  that earlier stages have changed.

**Fallback: copy-then-run.** For debugging (error line numbers match the real
files), copy the files to the Proxmox node and run them there:

```bash
tar -czf - scripts config | ssh root@192.168.88.101 'mkdir -p /root/serverlab && tar -xzf - -C /root/serverlab'
ssh -t root@192.168.88.101 '/root/serverlab/scripts/proxmox-node/networking.sh --dry-run'
```

Treat the copy as a throwaway snapshot: repeat the `tar` step after any local
change instead of editing it on the node.
