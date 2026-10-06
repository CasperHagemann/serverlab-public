# 0011. Documentation structure

Status: Accepted

Date: 2026-10-06

## Context

Docs that repeat each other drift. Readers and AI assistants need to know
where to look and where to write.

## Decision

- Root `README.md`: scope, where to start, layout, licence.
- `docs/design/<area>.md`: what is configured and how, in the format of
  `docs/design/README.md`: a description with an example value and a table
  of value effects for each config key. A Planned section holds what is not
  implemented.
- `docs/decisions/`: ADRs, kept short and linked from the other docs
  instead of repeated.
- `docs/runbooks/`: step-by-step procedures.
- Directory READMEs (`scripts/`, `config/`, `tests/`) hold how-to content
  only and link to the ADR that holds a rule.
- `memory-bank/` summarises the project for assistants and links to the
  owners.
- Terms and names follow [ADR-0002](0002-terminology-and-naming.md).
- `.clinerules/custom/adr-decisions.md` says which ADR applies to which
  kind of change.

## Consequences

- A rule is written once, in an ADR; READMEs and design docs link to it.
- Moving or renumbering an ADR means updating every link to it.
- ADR structure is checked by `scripts/control-node/check.sh`.
