# ADR-0002: No NAT Gateway; S3 gateway endpoint only

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Private subnets usually get outbound internet through a NAT Gateway. A NAT Gateway costs roughly $32+ per month per AZ plus data processing, which is a lot for a portfolio budget. The only private resource is RDS, and it doesn't need outbound internet access.

## Decision

- No NAT Gateway. The private route tables have no `0.0.0.0/0` route.
- Add a free **S3 gateway endpoint**, associated with both the public and the private route tables.
- The EC2 instance (in a public subnet) reaches Secrets Manager, CloudWatch Logs, KMS and SSM through their public endpoints using its public IP.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| NAT Gateway | Standard pattern; private hosts can download patches | ~$32+/month/AZ; wider egress; not needed |
| Interface endpoints for SSM, Secrets Manager, Logs, KMS | Control-plane calls never touch the public internet | ~$7–8 per endpoint per AZ per month (~$60+ for 4 endpoints × 2 AZs) |
| **Gateway endpoint only (chosen)** | Free; S3 traffic stays on the AWS network; makes the VPCE-only bucket policy possible | Control-plane calls from EC2 use public endpoints (still IAM-authenticated and TLS-encrypted) |

## Consequences

- The private tier is fully isolated from the internet, which is easy to prove with route table evidence.
- The endpoint must be associated with the public route table. Otherwise EC2 would reach S3 over the internet and the bucket's VPCE-only policy would deny it.
- Upgrade path: interface endpoints, together with the private app subnet described in ADR-0004.
