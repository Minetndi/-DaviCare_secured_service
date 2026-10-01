# ADR-0012: S3 gateway endpoint policy as a data perimeter

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

The S3 gateway endpoint (ADR-0002) is attached to both route tables, so **every** S3 request from the VPC goes through it. With the default endpoint policy (full access), an attacker who compromised the EC2 instance could copy synthetic records to a bucket in their own AWS account using their own credentials. The vault's bucket policy can't stop that, because the destination isn't the vault.

At the same time, the instance has to read a few AWS-owned buckets: Amazon Linux package repositories and the SSM agent's buckets.

## Decision

The endpoint policy allows:

1. Any S3 action on buckets owned by this account (`aws:ResourceAccount` equals the account ID).
2. `s3:GetObject` only, on the named AWS-owned buckets for package repositories and SSM in this region.

Everything else through the endpoint is implicitly denied.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Default full-access policy | Nothing can break | Open exfiltration path to any bucket |
| **Account-scoped + AWS-owned read-only (chosen)** | Blocks writes to foreign buckets; keeps patching and SSM working | Must list AWS bucket names, which can change |
| Restrict to the vault bucket only | Tightest | Breaks package installs, SSM and the state bucket |

## Consequences

- Copying data from the VPC to another account's bucket fails, and the failure shows in CloudTrail. This is checked in Phase 9 evidence.
- If AWS renames a repository or SSM bucket, `dnf` or the SSM agent fails with `AccessDenied`. The fix is to add that bucket to the list.
- Traffic to S3 in **other** regions doesn't use the endpoint. It leaves through the internet gateway with the instance's public IP, so this perimeter covers same-region S3 only. The instance role's own permissions (Phase 3) are the control for the rest.
