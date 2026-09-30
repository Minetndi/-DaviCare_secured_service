# ADR-0006: MySQL on Amazon RDS

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

The synthetic mother and child records are relational (mother → children → visits). A managed database lets the project focus on security controls instead of running a database.

## Decision

Use **Amazon RDS for MySQL** (8.x, `db.t4g.micro`, gp3) in the private subnets. It gets:

- KMS encryption
- `require_secure_transport=ON`
- encrypted automated backups
- deletion protection
- an RDS-managed master password stored in Secrets Manager

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **RDS MySQL (chosen)** | Matches the CV and the diagram; free-tier eligible; familiar | – |
| RDS PostgreSQL | Richer features | No security advantage here; the diagram specifies MySQL |
| Aurora Serverless v2 | Scales automatically | Higher minimum cost |
| DynamoDB | Serverless and cheap | Doesn't demonstrate network segmentation of a database tier |
| MySQL on EC2 | Full control | Patching and backups become our job; weaker story |

## Consequences

- Verification: `aws rds describe-db-instances` shows `PubliclyAccessible=false` and `StorageEncrypted=true` with the CMK. A connection without TLS is refused.
- Deletion protection must be turned off before `terraform destroy`. The teardown runbook covers this.
