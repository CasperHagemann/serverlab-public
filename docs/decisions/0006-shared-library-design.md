# 0006. Shared library design

Status: Accepted

Date: 2026-10-06

## Context

Several scripts need the same helpers (logging, prompts, config, `pvesh`
wrappers). One large shared file becomes hard to navigate, and a library
that does work when sourced makes scripts unpredictable.

## Decision

Shared code lives in `scripts/lib/`, one file per topic (`log.sh`,
`args.sh`, `guards.sh`, `prompt.sh`, `files.sh`, `config.sh`, `pve.sh`,
`net.sh`, `disk.sh`, and so on), loaded by `common.sh`, which only sources them. Each
file:

- Contains only function definitions; sourcing it has no side effects.
- Names functions `pkg::function`, where `pkg` is the file's topic.
- Has an include guard, so sourcing twice is harmless.
- Declares every function variable with `local`.
- Has a header comment above every function (scripts only comment the
  non-obvious ones, see ADR-0005): purpose, arguments, output and
  return value.
- Holds no node-specific values; those come from config or arguments.
- Is split when it covers more than one topic; there is no line limit.

## Consequences

- A function's file is known from its prefix.
- Libraries can be sourced by tests directly
  ([ADR-0007](0007-testing-and-quality-gates.md)).
- `remote-run.sh` can bundle the files without `common.sh`
  ([ADR-0010](0010-remote-execution.md)).
