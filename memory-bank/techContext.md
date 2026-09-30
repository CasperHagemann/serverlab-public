# Tech Context

## Development environment

- **OS:** CachyOS (Arch-based), default shell fish.
- **IDE:** VS Code. The integrated terminal defaults to `bash` via
  `.vscode/settings.json`, because Cline's shell integration does not
  complete reliably under fish. The setting is ignored in Workspace Trust
  Restricted Mode.
- **Packages:** `pacman` (no AUR) for project tooling. MCP servers run via
  `uvx`/`npx` (see below).

## Tools

| Tool         | Package                | Purpose                                          | Auto-fixes?       |
| ------------ | ---------------------- | ------------------------------------------------ | ----------------- |
| `shfmt`      | `shfmt`                | `.sh` formatting                                 | yes               |
| `prettier`   | `prettier`             | `.json`/`.md` formatting                         | yes               |
| `shellcheck` | `shellcheck`           | `.sh` correctness/lint                           | no — reports only |
| `ec`         | `editorconfig-checker` | `.editorconfig` compliance                       | no — reports only |
| `bats`       | `bats`                 | `tests/*.bats` unit tests for `scripts/lib/*.sh` | no — reports only |
| `gh`         | `github-cli`           | GitHub PR/repo operations                        | n/a               |

Install: `sudo pacman -S shfmt shellcheck editorconfig-checker prettier bats github-cli`

`bats` is development-environment only and never installed on Proxmox
hosts (ADR-0003, `scripts/README.md`). `tests/lib/*.bats` test
`scripts/lib/*.sh` using stub executables in `tests/fixtures/bin/`
(`pvesh`, `pvesm`, `sgdisk`). 42 tests. Layout: `tests/README.md`.

## MCP servers

| Server                | Command                                                   | Purpose                                          |
| --------------------- | --------------------------------------------------------- | ------------------------------------------------ |
| `fetch`               | `uvx mcp-server-fetch`                                    | Reads long web pages in chunks via `start_index` |
| `sequential-thinking` | `npx -y @modelcontextprotocol/server-sequential-thinking` | Step-by-step reasoning                           |

Versions are not pinned. `.cline/mcp.json` mirrors the Cline MCP settings
and is not read automatically (see `docs/dev-environment.md`).

## Setup

```bash
git clone <repo>
cd serverlab
./scripts/install-hooks.sh   # once per clone
./scripts/check.sh           # fix mode: format whole repo, run bats
./scripts/check.sh --check   # staged files only, no mutation (pre-commit)
```

## Technical constraints

- `editorconfig-checker` v4.0.2 has no working `.ecrc` support here;
  exclusions are passed with `-exclude` in `check.sh`.
- `ec` checks untracked files and ignores `.gitignore`.
- Prettier cannot format `.sh`, hence separate tools.
- `shellcheck` `SC1091` (sourced file not followed) is suppressed with
  `-S warning`.
- Under `set -e`, log messages placed after a failing command do not run;
  use `trap ... ERR`.

## Git / GitHub

- Repo-local git identity (not global). GitHub's "block pushes exposing
  email" setting is enabled.
- PRs: `gh pr create` or the web UI; squash-merge only (merge commits and
  rebase merges disabled). Default squash message: PR title.
- No CI. The pre-commit hook is local and bypassable.
