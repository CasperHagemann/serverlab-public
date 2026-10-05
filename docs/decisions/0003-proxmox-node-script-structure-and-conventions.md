# 0003. Proxmox-node script structure and conventions

Status: Accepted

Date: 2026-09-27

## Context

ADR-0002 settled on bash + `pvesh` for Proxmox-node configuration, but left the
concrete structure of individual scripts and shared code undefined. The
first real script (creating the general VM network bridge, `vmbr1`, since
the Proxmox installer only configures the management interface) forced
those decisions:

- How shared code should be organized as it grows, without becoming one
  large, hard-to-navigate file.
- What phases a Proxmox-node configuration script should go through so changes are
  safe and reviewable rather than applied blindly.
- Where node-specific values (NIC names, IPs) should live so the same
  script works unchanged across nodes.
- How scripts get run at all, given the Proxmox node may only be reachable over
  SSH, without a clone of this repo on it.
- How to verify shared library code and Proxmox-node scripts before committing,
  without adding test tooling to the Proxmox nodes themselves.

## Decision

**Shared code (`scripts/lib/`)**: split by topic into one file per concern
(`log.sh`, `guards.sh`, `prompt.sh`, `files.sh`, `config.sh`, `pve.sh`,
`net.sh`, `disk.sh`), loaded via a single `common.sh` that only sources them. Each
file:

- Contains only function definitions — sourcing it has no side effects.
- Uses `pkg::function` naming (e.g. `net::iface_exists`), matching the
  [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)'s
  convention for library functions.
- Has an include guard, so sourcing it twice is harmless.
- Declares every function-local variable with `local`.
- Is split further once it covers more than one topic (no fixed
  line-count rule).

The Google Shell Style Guide is adopted as the project's reference for
anything not already covered by `shfmt`/`shellcheck`.

**Scope**: the script-phase, rollback, idempotency and per-node config rules
below apply to scripts in `scripts/proxmox-node/`, which run on the Proxmox
node. Tooling in `scripts/control-node/` (`check.sh`, `install-hooks.sh`) and
`scripts/remote-run.sh` runs on the control node; only the shared-code,
strict-mode and style rules apply to them. The terms _control node_ and
_Proxmox node_ are defined in the root `README.md`. (Earlier revisions of
this ADR called the Proxmox-node scripts "host scripts" and kept them in
`scripts/host/`.)

**Shell script naming (`scripts/proxmox-node/NN-<area>.sh`)**: one script per
configuration area (e.g. `10-network.sh`, `20-storage.sh`), named after
what it configures rather than its current feature, so adding more to an
area (a second bridge, VLAN tagging, more storage entries) means adding
list-style config entries and a loop in the existing script/library, not a
new script. The `NN-` prefix fixes run order and leaves gaps for new
areas; split an area into `NNa-<area>-<detail>.sh` files only if it grows
too large for one script.

**Rollback**: on apply/verify failure, a script stops and prints the
exact manual undo command(s) (the backup path already made in phase 4)
rather than reverting automatically — this keeps scripts simple as more
areas/features are added, at the cost of requiring a human to run the
undo step. This applies to every script, including `10-network.sh`.

**Script phases**: beyond a trivial one-liner, a script has a `main`
function, called as `main "$@"` on its last line, that runs these phases in
order: (1) parse arguments/input — config file first, prompt only for what's
missing; (2) pre-flight checks — verify assumptions against real Proxmox-node
state, and if the target state already holds, log `Nothing to do.` as its own
last line and exit 0; (3) plan/diff/confirm —
show the change, honor `--dry-run`, prompt unless `--yes`; (4) back up and
stage; (5) apply; (6) post-verify — re-check Proxmox node state only (no
external reachability checks, e.g. pinging a gateway, since that can fail
for reasons unrelated to the script and would trigger a false failure),
stop and report on failure; (7) summary.

**Per-node config (`config/proxmox-nodes/<hostname>.env`)**: one file per Proxmox
node, plain `KEY=value` lines and comments only, always committed (no
secrets). Scripts default to `config/proxmox-nodes/$(hostname -f).env`, overridable
with `--config`. `config::load` rejects anything in the file beyond plain
assignments before sourcing it.

**Running on the Proxmox node (`scripts/remote-run.sh`)**: bundles
`scripts/lib/*.sh`, one or more stages (or `all`), and every Proxmox-node
config file into a single compressed command, run over one `ssh -t` call, so
stages can be run on a Proxmox node that has no clone of this repo, with
prompts still working and one login per run. The node picks the config file
that matches its own hostname. Each stage runs in its own subshell; the run
stops at the first failing stage. Stages never reboot the node: they call
`log::reboot_required`, which records a reminder in
`/run/serverlab/reboot-required` and is summarised at the end of the run. A
copy-then-run fallback (`tar` over SSH, then run in place) remains
documented for debugging, since it preserves real file/line numbers in
error output.

**Testing (`tests/`)**: shared library functions and development-environment-side
scripts are tested with [bats-core](https://github.com/bats-core/bats-core)
(`*.bats` files under `tests/`), run in the control node only — never
installed on Proxmox nodes, and required via `./scripts/control-node/check.sh`. Tests
source `scripts/lib/*.sh` directly and replace Proxmox-node-only commands (e.g.
`pvesh`) with stub executables placed first on `PATH`, so they can run
without a Proxmox node. Only functions with real branching/parsing logic
are covered (e.g. `pve::wait_task`'s polling loop, `net::default_gateway`'s
route-table parsing) — thin pass-through wrappers around a single external
command aren't worth a test. Behavior that depends on real Proxmox node state
(applying network changes, failure reporting, pre-flight refusals) is checked
manually against the Proxmox node via `scripts/remote-run.sh` — dry-run,
decline, `--yes` apply, then a no-op re-run — rather than by an automated
test runner. This four-case walkthrough is the standard, and deliberately
final, level of Proxmox-node verification for scripts like this one — an
automated Proxmox-node test runner was built and tried in an earlier iteration of
this decision, then removed once it was judged to be more code than the
scripts it tested; see the Consequences below. Plain `bats` assertions
are used; helper libraries (`bats-assert`, `bats-support`) can be adopted
later if assertions become repetitive.

## Consequences

- Adding a new Proxmox-node script means reusing existing `lib/` functions and
  following the same seven phases, rather than inventing structure each
  time — consistency across scripts, at the cost of some upfront
  boilerplate per script.
- Naming scripts after the area they configure (`10-network.sh`,
  `20-storage.sh`) rather than their current feature means most future
  additions extend an existing script/library instead of adding a new
  file — but it also means a script's own header comment and config keys
  need to stay a step ahead of "what it does today," describing the area
  in general terms even before a second feature in that area exists.
- Stop-and-report on failure (manual undo, printed as a command)
  keeps script logic simple as features are added, but depends on a human
  actually running the printed undo step — nothing currently enforces or
  automates that.
- Post-verify depends entirely on local, Proxmox-node-side checks. This avoids
  false failures from unreachable external equipment, but means a change
  that succeeds locally while breaking something outside the Proxmox node's own
  state (e.g. a misconfigured upstream switch) won't be caught by the
  script itself.
- The config file convention (`config/proxmox-nodes/<hostname>.env`, always
  committed) duplicates values already recorded in `inventory/` — both
  must be kept in sync manually; nothing currently enforces this
  automatically.
- `remote-run.sh` re-sends the full bundle on every invocation rather than
  relying on a persistent copy on the Proxmox node, so there's no drift between
  what's run and the current working tree, at the cost of slightly more
  SSH traffic per run.
- This decision covers single-script, single-node execution only.
  Composing or orchestrating scripts across multiple Proxmox nodes is out
  of its scope (see ADR-0002).
- Contributors need `bats` installed in their control node alongside the
  existing formatting/lint tools. Proxmox nodes stay free of extra packages,
  consistent with the "no extra Proxmox-node packages" convention.
- Deliberately minimal automated checks: bats only covers branching/parsing
  logic, and real Proxmox-node behavior (applying a network change)
  is verified manually rather than by a scripted Proxmox-node test runner. This
  keeps the test surface small and easy to maintain, at the cost of
  depending on someone remembering to actually run the manual walkthrough
  after changing a Proxmox-node script or `pve.sh`/`net.sh` — it can regress
  unnoticed between runs.
- The manual `remote-run.sh` walkthrough (dry-run, decline, `--yes`,
  no-op re-run) is the intended stopping point for Proxmox-node verification —
  future Proxmox-node scripts should be checked the same way, not by building a
  new automated Proxmox-node test harness. Ad hoc tooling is not
  introduced in its place.
