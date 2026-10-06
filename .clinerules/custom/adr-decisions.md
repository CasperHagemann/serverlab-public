# Architecture decision records (ADRs)

ADRs in `docs/decisions/` record the design decisions currently in force.
Code, config and docs must agree with them. `docs/design/` holds the
detailed target state; ADRs hold the decision and its reasoning.

## Before any change

- Read the index in `docs/decisions/README.md` and every ADR relevant to
  the change.
- If a change contradicts an ADR, stop. Name the ADR and the conflict, and
  proceed only after the user decides: change the plan, or update the ADR.
- Do not propose an option an ADR already rejected without saying that it
  was rejected and why.

## Which ADR applies

| Change to | Read |
| --- | --- |
| Terms, file, key or function names | ADR-0002 |
| Where a fact or file lives | ADR-0003 |
| Choice of tooling | ADR-0004 |
| Any shell code, options, exit status | ADR-0005 |
| `scripts/lib/` | ADR-0006 |
| Tests, `check.sh`, hooks | ADR-0007 |
| `scripts/proxmox-node/`, new area | ADR-0008 |
| `config/proxmox-nodes/*.env`, keys | ADR-0009 |
| `scripts/remote-run.sh` | ADR-0010 |
| Docs, READMEs, ADRs | ADR-0011 |
| Storage | ADR-0012 |
| CPU, I/O, memory priority | ADR-0013 |

## When an ADR is needed

Write or update an ADR when a decision:

- is hard or costly to reverse (tooling, storage, network layout,
  security model, repository structure);
- rejects a plausible alternative someone would otherwise re-propose;
- sets a convention that applies across scripts or docs.

Not for implementation detail, step-by-step procedures or configuration
values; those belong in `docs/design/`, `scripts/README.md` or `config/`.
When unsure, ask the user.

## Lifecycle

- An ADR describes the current decision. When the decision changes, update
  the ADR in place and set `Date:` to the day of the change; git history
  keeps earlier versions.
- When a decision no longer applies, delete the ADR and its index row.
- Do not create superseding ADRs or keep obsolete ones.
- Editorial fixes (typos, links, renamed paths or terms) do not change
  `Date:`.
- No to-do lists, task tracking or "revisit when" notes in ADRs. Tasks are
  tracked outside the repository; notes on planned work go in the Planned
  section of the relevant `docs/design/` doc.

## File and layout

- File: `docs/decisions/NNNN-short-title.md`: next free 4-digit number,
  lowercase kebab-case title.
- Title line: `# NNNN. Title` (number matches the file name).
- `Status: Proposed` until the user accepts it, then `Status: Accepted`.
- `Date: YYYY-MM-DD`.
- Sections, in this order: `## Context`, `## Decision`,
  `## Consequences`. No other top-level sections.
- Add or update the row in the index table in `docs/decisions/README.md`.

Skeleton:

```markdown
# NNNN. Title

Status: Proposed

Date: YYYY-MM-DD

## Context

## Decision

## Consequences
```

## Content (best effort)

Every ADR has all three sections. If a section or topic does not apply,
write one line stating why, e.g. "Not applicable: no realistic alternative
exists." A bare "N/A" or "None." is not enough; give the reason. Do not
delete the heading or leave it empty.

Context usually covers:

- the problem and why a decision is needed;
- constraints and scope that shape it (e.g. single node, single admin, no
  extra packages on the Proxmox node);
- the realistic options, including the current approach where one exists.

Decision usually covers:

- the chosen option, stated directly ("We use ...");
- rejected options and why, unless already given in Context;
- a link to the design doc or script that implements it.

Consequences usually covers:

- what becomes easier and what becomes harder;
- limitations and risks;
- what the decision does not cover, where that is not obvious.

Cover what is relevant; skip the rest without padding.

## Style

- Facts only: no marketing, no filler, no speculation without a stated
  basis.
- Plain prose and bullets; no coded bullets, front matter or tags.
- Use the project terminology: control node, Proxmox node.
- Keep it short; link to `docs/design/` instead of repeating it.

## Version-specific behaviour

When a change depends on behaviour that differs between versions (`pvesh`,
`pvesm`, `sgdisk`, `chronyc`, config file formats and paths, cgroup and
systemd behaviour, defaults and limits), check it. Do not rely on memory.
The versions in use are in `inventory/hardware.md`. Sources, in order:

1. The Proxmox node: `pveversion`, `man`, `--help`.
2. Official documentation for the same version, listed in
   `docs/design/README.md` under Sources.
3. General web results, only to find an official source.

## Verify

- Run `./scripts/control-node/check.sh` after any change. It validates
  file names, titles, status, date, section order, non-empty sections and
  the index, and runs shfmt, shellcheck, editorconfig and the bats tests.
  It does not check content; review it yourself.
