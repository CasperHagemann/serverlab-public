# 0001. Record architecture decisions

Status: Accepted

Date: 2026-10-02

## Context

The project involves non-trivial infrastructure decisions (toolstack,
networking, storage, security, backup, monitoring, clustering) made by a
single administrator over an extended timeline. Design docs in
`docs/design/` describe the target state but not why it was chosen or
which alternatives were rejected.

Options: no decision records; rationale inside the design docs; separate
decision records.

## Decision

We record significant decisions as ADRs in `docs/decisions/`, one file per
decision. An ADR describes the decision currently in force and is updated
when the decision changes; git history holds earlier versions. An ADR
whose decision no longer applies is deleted. Structure and workflow:
`.clinerules/custom/adr-decisions.md`.

Rationale inside the design docs was rejected: it mixes target state with
reasoning and makes rejected options hard to find.

## Consequences

- Readers can see why a decision was made and which options were rejected.
- `docs/decisions/` stays a small library of current decisions.
- Writing and maintaining an ADR takes effort for each significant
  decision.
- The reasoning behind replaced decisions is only available in git
  history.
