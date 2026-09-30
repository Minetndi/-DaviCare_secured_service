# DaviCare Secure Medical Data Vault

A secure healthcare data environment on AWS, built with Terraform, for **DaviCare**, a healthcare initiative focused on mothers and children.

> I built a secure healthcare data environment for DaviCare using AWS and Terraform. The goal was to demonstrate how sensitive healthcare data could be protected through network segmentation, least-privilege IAM, encryption, secure storage, and monitoring. I also designed the environment with future AI/LLM integration in mind, particularly around protecting sensitive data and preventing unauthorized access to AI services.

This is a **cloud security** project, not a healthcare product. The application layer is deliberately thin: it exists only to produce realistic data access and logs for the security controls to protect and record. **All data is synthetic.** No real patient information is used anywhere.

## Status

| Phase | Status |
|---|---|
| 0. Design: architecture, threat model, data classification, ADRs | Done |
| 1. Bootstrap: remote Terraform state | Not started |
| 2–8. Network, security core, data, compute, monitoring, AI foundation, CI + evidence | Not started |

See the full [project plan](docs/project-plan.md).

## Architecture at a glance

```
Internet ──443──► EC2 (public subnet, FastAPI, SSM only, IMDSv2)
                    │                     │
                    │ 3306 (TLS)          │ S3 gateway endpoint
                    ▼                     ▼
            RDS MySQL (private,     S3 data vault (KMS CMK, BPA,
            KMS, no public IP)      versioning, TLS + VPCE-only)

Security layer: IAM · Security Groups · KMS · CloudTrail · CloudWatch · Flow Logs · SNS
```

Details: [docs/architecture.md](docs/architecture.md)

## Security controls summary

| Area | Controls |
|---|---|
| Network segmentation | Public/private tiers, no internet route from private subnets, chained security groups (443 → EC2 → 3306 → RDS), no SSH, VPC Flow Logs |
| Least-privilege IAM | Scoped instance role, no wildcard actions/resources, permissions boundary, MFA break-glass role, auditor role, GitHub OIDC (no access keys), Access Analyzer |
| Encryption | Customer-managed KMS keys (data, logs) with rotation; TLS enforced to RDS and S3 |
| Secure storage | Block Public Access, ACLs disabled, SSE-KMS required, VPC-endpoint-only bucket policy, versioning, access logging |
| Monitoring | Multi-region CloudTrail with validation and S3 data events, CIS-style metric filters and alarms to SNS, budget alert, PHI-free app audit log |
| AI/LLM (designed) | Private Bedrock endpoint, model-scoped invoker role, Guardrails (PII masking, prompt-attack filter), invocation logging |

## Documentation

- [Project plan](docs/project-plan.md)
- [Architecture](docs/architecture.md)
- [Threat model (STRIDE)](docs/threat-model.md)
- [Data classification](docs/data-classification.md)
- [Architecture decision records](docs/adr/README.md)
- Runbooks (`docs/runbooks/`) and evidence (`docs/evidence/`) are added in later phases.

## Repository layout

```
infra/        Terraform: bootstrap, modules (network, security, compute, database, storage, monitoring, ai_foundation), envs/dev
app/          Thin FastAPI app
scripts/      Synthetic data generator and verification scripts
docs/         Plan, architecture, threat model, classification, ADRs, runbooks, evidence
.github/      CI workflows
```

## Deploy / destroy

To be written in Phase 1. The intended workflow is deploy → capture evidence → `terraform destroy`, to keep costs low.

## Cost notes

The design avoids a NAT Gateway, interface endpoints and Multi-AZ RDS. See [cost notes in the plan](docs/project-plan.md#6-cost-notes-rough-estimates-for-a-dev-environment).
