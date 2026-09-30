# Threat Model (STRIDE)

## Scope and assumptions

- **In scope:** the AWS environment in [architecture.md](architecture.md), the thin FastAPI app, the Terraform pipeline and state.
- **Assets:** synthetic PHI in RDS and S3, DB credentials, KMS keys, audit logs, Terraform state, the CI identity.
- **Adversaries:** an internet attacker, a compromised app process, a malicious or careless insider with some AWS access, and a compromised CI pipeline or dependency.
- **Assumptions:** the AWS account root is protected with MFA and not used day to day. AWS itself is trusted. The data is synthetic, but it's treated as real PHI.
- **Out of scope:** DDoS at scale, physical attacks, app-level user authentication beyond a simple demo mechanism.

## Trust boundaries

1. Internet ↔ EC2 (port 443)
2. EC2 ↔ RDS (private subnet, port 3306)
3. EC2 ↔ S3 vault (gateway endpoint)
4. EC2 ↔ AWS control-plane APIs (Secrets Manager, KMS, Logs, SSM)
5. Human / CI ↔ AWS account (IAM roles, OIDC)
6. *(Future)* EC2 ↔ Bedrock (interface endpoint)

## STRIDE by component

S = Spoofing · T = Tampering · R = Repudiation · I = Information disclosure · D = Denial of service · E = Elevation of privilege

### EC2 app server

| | Threat | Mitigation |
|---|---|---|
| S | Attacker steals instance role credentials through SSRF to the metadata service | IMDSv2 required with hop limit 1; the role is scoped so stolen credentials can do little; CloudTrail shows role use from unexpected sources |
| T | Attacker modifies the app or OS | No SSH or key pair; admin only via SSM with an MFA role; SG and IAM change alarms |
| R | Actions can't be tied to a user | JSON audit log per request; CloudTrail for every API call |
| I | App leaks PHI in logs or errors | PHI-free logging rules ([data-classification.md](data-classification.md)); generic error responses |
| I | SQL injection exposes records | Parameterized queries only; app DB user limited to its schema |
| D | Traffic flood on 443 | Accepted risk for a dev demo; optional ALB + WAF in the hardening ADR |
| E | Compromised app process escalates in AWS | No `*` in policies; permissions boundary; no `iam:*` for the app role |

### RDS MySQL

| | Threat | Mitigation |
|---|---|---|
| S | Unauthorized client connects | No public access; SG allows only the EC2 SG; credentials in Secrets Manager |
| T | Records altered or dropped | App user has SELECT/INSERT only (no DROP/ALTER); automated encrypted backups; deletion protection |
| R | Data changes are untraceable | App audit log; RDS logs optional |
| I | Traffic sniffed or snapshot shared | `require_secure_transport=ON`; storage and snapshots encrypted with the CMK, so a shared snapshot is useless without key access |
| D | Resource exhaustion | CPU and connection alarms |
| E | App uses master credentials | Separate app DB user; master secret not readable by the instance role |

### S3 data vault

| | Threat | Mitigation |
|---|---|---|
| S | Requests from outside the VPC using leaked credentials | Bucket policy allows access only through the VPC endpoint (plus a break-glass carve-out) |
| T | Objects overwritten or deleted | Versioning; lifecycle only removes non-current versions; optional Object Lock |
| R | Object access not attributable | CloudTrail S3 data events; server access logs |
| I | Bucket made public or objects stored unencrypted | Account + bucket Block Public Access; ACLs disabled; deny PutObject without SSE-KMS; deny non-TLS; policy change alarm |
| D | Key disabled makes data unreadable | KMS disable/deletion alarm; 30-day deletion window |
| E | App reads outside its prefix | Role limited to `records/*` on this bucket |

### KMS keys

| | Threat | Mitigation |
|---|---|---|
| T / D | Key disabled or scheduled for deletion | Alarm on `DisableKey` / `ScheduleKeyDeletion`; key admin limited to break-glass role |
| I | Key used by an unintended principal | Key policies list specific roles and services; `kms:ViaService` condition on the app role |
| R | Key use not audited | CloudTrail records every KMS call |

### Logging and monitoring

| | Threat | Mitigation |
|---|---|---|
| T | Attacker edits or deletes logs | CloudTrail log file validation; dedicated bucket writable only by CloudTrail; logs CMK separate from the data CMK |
| R / D | Trail stopped to hide activity | Alarm on `StopLogging` / `DeleteTrail` / `UpdateTrail` |
| I | Logs themselves contain PHI | PHI-free logging rules; logs encrypted with the logs CMK |

### Terraform state and CI/CD

| | Threat | Mitigation |
|---|---|---|
| S | Stolen long-lived CI keys | GitHub OIDC with trust limited to this repo and branch; no access keys |
| T | State tampered with or corrupted | Versioned, encrypted state bucket; S3-native locking; TLS-only policy |
| I | Secrets leak via state or commits | RDS-managed passwords keep secrets out of state; gitleaks in CI; `.gitignore` for tfvars and state |
| E | Malicious PR changes infra | Plan on PRs, apply only from the protected main branch; Checkov/Trivy checks |

### IAM (humans)

| | Threat | Mitigation |
|---|---|---|
| S | Console login without MFA | Alarm on console login without MFA; break-glass role requires MFA |
| E | Policy changes grant new rights | Alarm on IAM policy changes; permissions boundary; Access Analyzer |
| E | Root account used | Root usage alarm |

### Future: Bedrock / LLM (disabled)

| | Threat | Mitigation |
|---|---|---|
| I | Prompt with PHI crosses the internet | Bedrock via VPC interface endpoint |
| E | App or user invokes unapproved models | `ai-invoker` role with model ARN allow-list and explicit deny; endpoint policy restricted to that role |
| T / I | Prompt injection extracts other patients' data | Guardrails prompt-attack filter; retrieval limited to data the caller may already read |
| I | Model output includes PHI | Guardrails PII masking on input and output |
| R | AI use unaudited | Model invocation logging (KMS-encrypted) plus CloudTrail |

The full OWASP LLM Top 10 mapping goes in `docs/ai-security.md` (Phase 7).

## Residual risks (accepted for a dev portfolio environment)

| Risk | Why it's accepted | Upgrade path |
|---|---|---|
| EC2 directly exposed on 443 in a public subnet | Cost and simplicity; only 443 open, no SSH | ALB + WAF + private app subnet (ADR-0004) |
| Single-AZ RDS | Cost | Multi-AZ (ADR-0007) |
| Control-plane calls use public AWS endpoints | Avoids around $45+/month of interface endpoints | Interface endpoints (ADR-0002) |
| Self-signed TLS certificate on EC2 | No custom domain | ACM certificate on an ALB |
| No GuardDuty, Security Hub or Config | Cost | Listed in Deferred |
