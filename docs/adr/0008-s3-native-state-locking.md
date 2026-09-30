# ADR-0008: S3-native Terraform state locking

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Terraform state contains resource IDs, ARNs and configuration, so it's classified **Confidential**. It needs encrypted remote storage and locking. Terraform 1.10 and later can lock directly in S3 (`use_lockfile = true`), and locking through DynamoDB is deprecated.

## Decision

- A `bootstrap/` configuration creates the state bucket with KMS encryption, versioning, Block Public Access and a TLS-only bucket policy.
- The backend uses `use_lockfile = true`. There's no DynamoDB table.
- Terraform 1.10 or later is required.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **S3-native locking (chosen)** | One fewer resource; the current recommendation | Needs Terraform 1.10+ |
| S3 + DynamoDB lock table | Widely documented | Deprecated; an extra resource |
| HCP Terraform | Managed state and runs | An external service; less to demonstrate in AWS |

## Consequences

- The bootstrap stack uses local state once, to create the bucket. That local state file is kept out of Git.
- RDS-managed passwords (ADR-0009) keep secrets out of state.
