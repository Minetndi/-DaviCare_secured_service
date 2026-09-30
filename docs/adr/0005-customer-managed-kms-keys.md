# ADR-0005: Customer-managed KMS keys, split data/logs

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

AWS-managed keys (`aws/s3`, `aws/rds`, `aws/ebs`) encrypt data at rest for free. However, their key policies can't be edited, their use can't be restricted to specific principals, and they can't be disabled.

## Decision

Create two customer-managed keys (CMKs), each with automatic rotation enabled:

| Key | Encrypts | Allowed users |
|---|---|---|
| `davicare-data` | RDS storage and snapshots, S3 vault objects, EBS volumes | App instance role (via S3/RDS/EC2 only, using `kms:ViaService`), RDS, EC2 and Auto Scaling services |
| `davicare-logs` | CloudTrail, VPC Flow Logs, CloudWatch log groups | CloudTrail and CloudWatch Logs services; the auditor role (decrypt, to read trails) |

Only the break-glass admin role can administer the keys. The deletion window is 30 days.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| AWS-managed keys | Free, no configuration | No policy control; can't show least privilege at the key level |
| One CMK for everything | Simpler, $1/month | Anyone who can read logs could also decrypt data; bigger blast radius |
| **Two CMKs (chosen)** | Separation of duties; fine-grained key policies; strong evidence | ~$2/month; more policy work |
| One CMK per service | Finest control | More cost and complexity than needed |

## Consequences

- Auditors can read logs without being able to decrypt patient data.
- Disabling a key or scheduling its deletion triggers an alarm (Phase 6).
- A mistake in a key policy can lock services out, so Terraform plans are reviewed and the root account statement is kept as a recovery path.
