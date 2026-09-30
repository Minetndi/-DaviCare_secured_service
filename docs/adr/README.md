# Architecture Decision Records

Each significant design decision is recorded here in a lightweight format: context, decision, alternatives and consequences. New ADRs copy [0000-template.md](0000-template.md). Superseded ADRs stay in place with their status updated.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-no-nat-gateway.md) | No NAT Gateway; S3 gateway endpoint only | Accepted |
| [0003](0003-ssm-instead-of-ssh.md) | SSM Session Manager instead of SSH | Accepted |
| [0004](0004-ec2-in-public-subnet.md) | EC2 in a public subnet (ALB + private subnet as stretch) | Accepted |
| [0005](0005-customer-managed-kms-keys.md) | Customer-managed KMS keys, split data/logs | Accepted |
| [0006](0006-mysql-on-rds.md) | MySQL on Amazon RDS | Accepted |
| [0007](0007-single-az-rds.md) | Single-AZ RDS for the dev environment | Accepted |
| [0008](0008-s3-native-state-locking.md) | S3-native Terraform state locking | Accepted |
| [0009](0009-app-db-user.md) | Dedicated least-privilege app DB user | Accepted |
| [0010](0010-app-proxies-s3-documents.md) | App proxies S3 document transfers | Accepted |
| [0011](0011-bootstrap-stack-scope.md) | Bootstrap stack scope: state key, plan-only CI role, budget | Accepted |

Planned: scanner exceptions (Phase 8), AI foundation design (Phase 7).
