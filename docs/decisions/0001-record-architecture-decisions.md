# 1. Record architecture decisions

Status: Accepted

Date: 2026-09-22

## Context

This project involves a series of non-trivial infrastructure decisions
(toolstack, networking, storage, security, backup, monitoring, clustering)
made over an extended timeline. Design docs (`docs/design/`) describe current intended state, but
don't capture _why_ a decision was made or what alternatives were rejected.

## Decision

We will use Architecture Decision Records (ADRs), stored in
`docs/decisions/`, to record significant decisions as they are made. Each ADR
is a short, immutable record: context, decision, consequences. If a decision
is later changed, a new ADR is written that supersedes the old one; the old
ADR is kept, not deleted or edited.

## Consequences

- Future readers (including the author) can see why a decision was made, not
  just what the current state is.
- Some overhead in writing an ADR for each significant decision.
- Design docs and ADRs must be kept distinct in purpose: design docs describe
  current target state and are living documents; ADRs are historical record
  and are not edited after acceptance.
