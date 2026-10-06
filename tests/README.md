# Tests

Unit tests for `scripts/lib/*.sh`, using [bats-core](https://github.com/bats-core/bats-core).
Control-node only — never installed on Proxmox nodes (see
[ADR-0007](../docs/decisions/0007-testing-and-quality-gates.md)).

## Running

```bash
bats tests/               # whole suite, recursively
bats tests/lib/net.bats   # a single file
./scripts/control-node/check.sh
```

`check.sh` also runs the whole suite, in fix mode only. The staged-files
pre-commit hook does not run the tests.

## Layout

- `tests/lib/*.bats` — one file per `scripts/lib/*.sh` file, same base name.
- `tests/fixtures/bin/` — stub executables placed first on `PATH` so tests
  can exercise code that normally calls Proxmox-node-only tools: `pvesh`, `pvesm`,
  and `sgdisk`. Each stub's header comment lists the environment variables
  that control its behavior.

## Conventions

What to test and what to check by hand is in
[ADR-0007](../docs/decisions/0007-testing-and-quality-gates.md). Practical
hints:

- Source the library file directly, not `common.sh`, so a test depends only
  on what its file needs.
- Call a function directly, not through `run`, when the test must see a
  variable it sets: `run` uses a subshell.
