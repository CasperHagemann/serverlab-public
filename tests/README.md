# Tests

Unit tests for `scripts/lib/*.sh`, using [bats-core](https://github.com/bats-core/bats-core).
Development-environment only — never installed on Proxmox hosts (see
[`docs/decisions/0003-host-script-structure-and-conventions.md`](../docs/decisions/0003-host-script-structure-and-conventions.md)).

## Running

```bash
bats tests/                 # whole suite, recursively
bats tests/lib/net.bats      # a single file
./scripts/check.sh           # runs the whole suite too (fix mode only —
                              # see scripts/check.sh; not part of the
                              # staged-files pre-commit hook)
```

## Layout

- `tests/lib/*.bats` — one file per `scripts/lib/*.sh` file, same base name.
- `tests/fixtures/bin/` — stub executables placed first on `PATH` so tests
  can exercise code that normally calls host-only tools: `pvesh`, `pvesm`,
  and `sgdisk`. Each stub's header comment lists the environment variables
  that control its behavior.

## Conventions

- Tests source the library file directly (`source
"${BATS_TEST_DIRNAME}/../../scripts/lib/<name>.sh"`) rather than going
  through `common.sh`, so each file's tests only depend on what that file
  itself needs.
- Prefer calling the function directly (not via bats' `run`) when a test
  needs to observe a side effect in the test's own shell afterward (e.g.
  a variable `prompt::value` or `config::load` assigned) — `run` forks a
  subshell, so changes made inside it aren't visible to the rest of the
  test.
- **Only functions with branching/parsing logic are tested** — e.g.
  `pve::wait_task`'s polling loop, `net::iface_addrs --global`'s scope
  filtering, `net::default_gateway`'s route-table parsing. Thin
  pass-through wrappers around a single external command (most of
  `pve.sh`, much of `net.sh`) are not tested.
- Behavior that depends on real Proxmox/host state (applying network
  changes, pre-flight refusals against the live network config) is
  verified manually against the host via `scripts/remote-run.sh`: dry-run,
  decline, `--yes` apply, then a no-op re-run. See
  [ADR-0003](../docs/decisions/0003-host-script-structure-and-conventions.md).
