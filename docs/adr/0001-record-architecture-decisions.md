# ADR-0001: Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

This project exists to show security engineering judgment, not only working infrastructure. Reviewers need to see *why* each control was chosen, what was traded off and which risks were accepted.

## Decision

Record every significant decision as a short Markdown ADR in `docs/adr/`, numbered in sequence, using [0000-template.md](0000-template.md). Scanner findings that are deliberately left unfixed also get an ADR.

## Consequences

- Decisions and trade-offs are reviewable in GitHub alongside the code.
- Accepted risks are stated explicitly and link to the [threat model](../threat-model.md).
- Each decision takes a little extra writing.
