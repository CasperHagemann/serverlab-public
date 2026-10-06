# 0005. Shell coding standards

Status: Accepted

Date: 2026-10-06

## Context

All automation is bash ([ADR-0004](0004-use-bash-and-proxmox-native-tooling.md)).
Without one style, each script gets its own habits and reviews turn into
style discussions. The
[Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
is widely known and complete.

## Decision

All shell code follows the Google Shell Style Guide. The guide wins over local
habit; a deviation needs a good reason and is listed under Deviations.

Settings the guide leaves to tools:

- Formatting is done by `shfmt` using `.editorconfig`: 2-space indent, no
  tabs, indented `case` patterns.
- `shellcheck -S warning` must pass.
- Lines are at most 80 columns, checked by `scripts/control-node/check.sh`.

Project rules on top of the guide:

- `#!/usr/bin/env bash` and `set -euo pipefail` in every executable.
- Every script has a `main` function, called as `main "$@"` on the last
  line, unless it is a trivial one-liner.
- Every script accepts `-h`/`--help`, which prints the options and the exit
  status. An unknown option is a usage error (exit 2).
- Exit status: 0 success (including nothing to do, `--dry-run`, `--help`),
  1 failure, 2 usage error, 3 declined at the confirmation prompt.
- `log::die [--code <n>] <message>` prints to stderr and exits.

### Deviations

- Length: the guide says to rewrite a script in another language once it
  passes 100 lines. Scripts here may be longer, because bash is a deliberate
  choice ([ADR-0004](0004-use-bash-and-proxmox-native-tooling.md)).
- Function comments: the guide asks for a comment on a function that is not
  both obvious and short. Library functions always have one
  ([ADR-0006](0006-shared-library-design.md)); in scripts, only the
  non-obvious ones do. The phase functions (`parse_args`, `preflight`,
  `plan_and_confirm`, `apply_change`, `verify_change`, `main`) are described
  once in [ADR-0008](0008-proxmox-node-script-contract.md).

## Consequences

- Style is not discussed in review; the tools decide.
- Existing code that differs from the guide is fixed, not grandfathered.
- Callers such as `remote-run.sh` can tell a decline from a failure.
