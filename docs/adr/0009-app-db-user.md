# ADR-0009: Dedicated least-privilege app DB user

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

The RDS master user has full privileges. If the app connected as the master user, SQL injection or a compromised process could drop tables, create users or read every schema.

## Decision

- RDS manages the master password in Secrets Manager. The app instance role **can't** read it.
- A one-time setup step, run over SSM, creates `davicare_app` with `SELECT, INSERT, UPDATE` on the `davicare` schema only. It gets no `DROP`, `ALTER` or `GRANT`, and no access to other schemas.
- The app user's password is kept in its own Secrets Manager secret. That's the only secret the instance role can read.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| App uses the master user | Simplest | Breaks least privilege |
| **App DB user + Secrets Manager (chosen)** | Clear least privilege; easy to prove with a `DROP TABLE` that fails | An extra setup step; password rotation to add later |
| IAM database authentication | No password; 15-minute tokens | Connection-rate limits; more app complexity. A good follow-up. |

## Consequences

- Verification: `DROP TABLE` run as `davicare_app` fails with an access error, and reading the master secret from EC2 returns `AccessDenied`.
