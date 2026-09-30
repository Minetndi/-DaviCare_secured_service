# ADR-0007: Single-AZ RDS for the dev environment

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Multi-AZ RDS roughly doubles the database cost. This is a short-lived dev environment with synthetic data. Availability isn't a goal here; confidentiality and integrity are.

## Decision

Deploy RDS as single-AZ. The DB subnet group still spans two AZs, so switching to Multi-AZ is a one-line change.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Single-AZ (chosen)** | Lowest cost | An AZ outage takes the database down |
| Multi-AZ | Automatic failover | About twice the cost, with no security benefit for this demo |

## Consequences

- The availability risk is accepted in the threat model. Automated backups still allow recovery.
- Upgrade path: set `multi_az = true`.
