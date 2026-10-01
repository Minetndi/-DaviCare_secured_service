# DaviCare Secure Medical Data Vault: Project Plan (v2)

**Stack:** AWS · Terraform · IAM · VPC · S3 · RDS · KMS · CloudWatch · CloudTrail · AI/LLM security

## Context

DaviCare is a healthcare initiative for mothers and children. This portfolio project shows how DaviCare could store and process sensitive healthcare data securely on AWS, with groundwork for adding AI features later.

The focus is **cloud security**. The app layer is kept thin on purpose. It exists only to create realistic traffic, data access and logs for the security controls to protect and record.

**The statement the finished project must support:**

> "I built a secure healthcare data environment for DaviCare using AWS and Terraform. The goal was to demonstrate how sensitive healthcare data could be protected through network segmentation, least-privilege IAM, encryption, secure storage, and monitoring. I also designed the environment with future AI/LLM integration in mind, particularly around protecting sensitive data and preventing unauthorized access to AI services."

**Where the project proves each CV claim:**

| CV claim | Where the project proves it |
|---|---|
| Secure AWS infrastructure with Terraform: VPC, IAM, S3, EC2, RDS, KMS | `infra/modules/*` (§3) |
| Least privilege, network segmentation, encryption, logging, monitoring | Controls in §4, evidence in §9 |
| Documenting infrastructure, security configs and architecture decisions in GitHub | `docs/`, ADRs, README (§7) |

**Constraints:** All data is synthetic (fake mother and child records). The budget isn't fixed yet, so the design avoids costly defaults such as a NAT Gateway, interface endpoints you don't need, and Multi-AZ RDS.

---

## 1. Architecture

```
                          DAVICARE
                             │
                    ┌────────▼─────────┐
                    │ VPC 10.0.0.0/16  │   (2 AZs, VPC Flow Logs ON)
                    └────────┬─────────┘
             ┌───────────────┴────────────────┐
     PUBLIC SUBNETS                    PRIVATE SUBNETS
     10.0.1.0/24, 10.0.2.0/24          10.0.11.0/24, 10.0.12.0/24
             │                                 │
       EC2 / App  ───── SG: 3306 only ────►  RDS MySQL
   (HTTPS 443 in; no SSH;               (no public IP, KMS-encrypted,
    admin via SSM Session Manager)       TLS required, deletion protection)
             │
             └── S3 Gateway Endpoint ──►  Secure S3 Data Vault
                 (on public + private       (KMS CMK, Block Public Access,
                  route tables)              versioning, TLS + VPCE-only policy)

 ┌──────────────────────────── SECURITY LAYER ────────────────────────────┐
 │ IAM │ Security Groups │ KMS │ CloudTrail │ CloudWatch │ Flow Logs │ SNS │
 └────────────────────────────────────────────────────────────────────────┘
```

### Design decisions (each recorded as an ADR in `docs/adr/`)

- **EC2 in a public subnet** (matches the diagram).
  - Only port 443 is open inbound. Port 22 is closed, there is no key pair, and admin access goes through SSM Session Manager.
  - IMDSv2 is required, with a hop limit of 1. The EBS volume is encrypted with the data CMK.
  - The instance reaches SSM, Secrets Manager and CloudWatch Logs over their public endpoints using its public IP. That's free, and every call is still authenticated with IAM and encrypted with TLS.
  - *Hardening stretch goal (ADR):* put an ALB in the public subnets, move EC2 into a private app subnet, and add interface endpoints for SSM, Secrets Manager and Logs. The ADR records the cost (about $7–8 per endpoint per AZ per month) against the security benefit.
- **RDS MySQL in the private subnets.**
  - Public access is off. Its security group allows 3306 only from the EC2 security group.
  - Encryption at rest uses the data CMK. `require_secure_transport=ON` is set in the parameter group.
  - Backups are encrypted, deletion protection is on, and it runs single-AZ to save cost (ADR).
- **Credentials.**
  - The master password is managed by RDS and stored in Secrets Manager. It never appears in Terraform variables, user data, state or Git.
  - The app connects as a **separate, least-privilege DB user** that can only SELECT and INSERT on its own schema, never as the master user. IAM database authentication is an option, compared in an ADR.
- **No NAT Gateway.** The private route tables have no internet route. S3 is reached through a free gateway endpoint. The endpoint is attached to the public route table too, so EC2 traffic to S3 stays on the AWS network and the bucket's VPCE-only policy works.
- **Terraform state** lives in an encrypted, versioned S3 bucket using S3-native locking (`use_lockfile`, Terraform 1.10+). No DynamoDB table is needed.

---

## 2. Minimal application layer (deliberately thin)

- **Backend:** FastAPI on EC2. Endpoints:
  - create and read synthetic patient records (mother or child)
  - upload or download a document in the S3 vault, proxied through the app (pre-signed URLs to the client would be denied by the VPC-endpoint-only bucket policy; see ADR-0010)
  - a health check
- **Frontend (optional):** one Next.js (TypeScript) page, or just the FastAPI Swagger UI. Drop it first if time is short.
- **Security behavior it demonstrates:**
  - parameterized queries
  - TLS to RDS with certificate verification against the RDS CA bundle
  - IAM role credentials from IMDSv2, with no access keys
  - DB credentials pulled from Secrets Manager at runtime
  - structured JSON audit logs sent to CloudWatch (who, what record ID, which action, when), with no raw PHI
- **Synthetic data:** a generator script creates clearly fake records (Faker-based, with a `SYNTHETIC` marker on every row).

---

## 3. Repository and Terraform layout

```
davicare-secure-vault/
  infra/
    bootstrap/        state bucket (KMS, versioning, BPA, TLS-only policy), S3-native locking
    modules/
      network/        VPC, 2-AZ public/private subnets, IGW, route tables, S3 gateway endpoint, Flow Logs, optional NACLs
      security/       KMS keys (data, logs), security groups, IAM roles/policies, permissions boundary, Access Analyzer
      compute/        EC2 (IMDSv2, encrypted EBS, SSM, instance profile, no key pair), app log group
      database/       RDS MySQL, subnet group, parameter group (TLS), managed master secret
      storage/        S3 vault + access-log bucket, bucket policies, versioning, lifecycle
      monitoring/     CloudTrail (+ S3 data events on the vault), log groups, metric filters, alarms, SNS, AWS Budget
      ai_foundation/  disabled by default: Bedrock interface endpoint, ai-invoker role, guardrail, invocation logging (§5)
    envs/dev/         root module: wiring, variables, outputs, default tags
  app/                FastAPI (+ optional Next.js page)
  scripts/            synthetic data generator, verification scripts for §9
  docs/               architecture, threat model, data classification, ai-security, adr/, runbooks/, evidence/
  .github/workflows/  fmt/validate/plan, Checkov, Trivy (tfsec's successor), gitleaks; GitHub OIDC to AWS
  README.md
```

---

## 4. Security controls

### Network segmentation
- The public and private tiers are separate, and the private route tables have no internet route.
- Security groups are chained: internet → **443** → EC2 SG → **3306** → RDS SG. Nothing else is allowed inbound. Outbound from EC2 is limited to 443 and 3306.
- The default security group is locked down to no rules.
- Optional NACLs on the private subnets allow only VPC CIDR traffic, as defense in depth.
- VPC Flow Logs go to CloudWatch Logs, encrypted with the logs CMK, with a set retention period.

### Least-privilege IAM
- **EC2 instance role** gets only:
  - `s3:GetObject`/`PutObject` on `vault-bucket/records/*`
  - `kms:Decrypt`/`GenerateDataKey` on the data key, restricted with `kms:ViaService`
  - `secretsmanager:GetSecretValue` on the app DB secret only
  - `logs:PutLogEvents` on its own log group
  - `AmazonSSMManagedInstanceCore`
- App policies contain no `*` actions and no `*` resources. A **permissions boundary** caps the role.
- Other roles: a **read-only auditor** role, and a **break-glass admin** role that requires MFA.
- No IAM users have access keys. CI authenticates with **GitHub OIDC**, limited to this repo and branch.
- **IAM Access Analyzer** is enabled to flag external access. Unused-access findings are optional because they're a paid feature.

### Encryption
- **Customer-managed KMS keys** with automatic rotation:
  - `davicare-data` for RDS, the S3 vault and EBS
  - `davicare-logs` for CloudTrail, Flow Logs and CloudWatch log groups
- Key policies name the specific roles and services that may use each key. There are no account-wide grants beyond the root admin statement.
- **In transit:**
  - HTTPS on EC2 (self-signed cert, or ACM behind the optional ALB)
  - TLS enforced by RDS
  - the S3 bucket policy denies requests where `aws:SecureTransport = false`

### Secure storage (S3 data vault)
- Block Public Access is on at both the account and bucket level. Object Ownership is set to *BucketOwnerEnforced*, so ACLs are disabled.
- The bucket policy denies:
  - any PutObject that doesn't use SSE-KMS with the data key
  - any request not made over TLS
  - any access that doesn't come through the VPC endpoint (with a carve-out for the break-glass/Terraform role, so it can't lock you out)
- Versioning is on. Server access logs go to a separate log bucket. A lifecycle rule expires old versions to control cost.
- Optional stretch: Object Lock in governance mode for audit evidence.

### Logging and monitoring
- **CloudTrail:** multi-region, log file validation on, a KMS-encrypted bucket that only CloudTrail can write to, CloudWatch Logs integration, and **S3 data events for the vault bucket** so object-level access is recorded.
- **Metric filters and alarms, sent to SNS email:** root account use, IAM policy changes, security group changes, KMS key disabled or scheduled for deletion, S3 bucket policy changes, console login without MFA, repeated `AccessDenied`/`UnauthorizedOperation` errors, RDS CPU or connection spikes.
- **AWS Budgets** alert at a small monthly threshold (for example $20), to protect against a forgotten deployment. Created in the bootstrap stack so it survives teardown (ADR-0011).
- **App audit log:** JSON records of who accessed which synthetic record ID and when, with no PHI fields.

---

## 5. AI/LLM security foundation (design first, build as a stretch goal)

The core deliverable is documentation plus Terraform that is written but **switched off** (`enable_ai_foundation = false`).

- **Private path:** Amazon Bedrock is reached through a VPC interface endpoint, so prompts with health data never cross the public internet.
- **Preventing unauthorized AI access:** a dedicated `ai-invoker` role can call `bedrock:InvokeModel` only on specific approved model ARNs; an explicit deny covers every other model; the endpoint policy only allows that role; the app role can't invoke models directly.
- **Protecting sensitive data:** Bedrock Guardrails with PII detection and masking, a prompt-attack (injection) filter, and denied topics (diagnosis and dosage advice). Retrieval honors the caller's existing authorization; the AI never gets broader data access than the user has.
- **Auditability:** Bedrock model invocation logging goes to a KMS-encrypted bucket or log group. CloudTrail records every invoke call.
- **Threat model:** `docs/ai-security.md` maps the controls to the **OWASP Top 10 for LLM Applications**.
- **Stretch goal:** turn the flag on, add one FastAPI endpoint that summarizes a synthetic record through Bedrock, and capture evidence of a blocked injection attempt and of masked PII.

---

## 6. Cost notes (rough estimates for a dev environment)

| Item | Approach | Rough cost |
|---|---|---|
| EC2 | t4g.micro / t3.micro | Low, or free tier |
| RDS | db.t4g.micro, single-AZ, 20 GB | Low, or free tier |
| KMS | 3 CMKs (data, logs, tfstate) | about $1 per key per month |
| NAT Gateway | **none** | $0 |
| S3 gateway endpoint | yes | $0 |
| Interface endpoints | only in the stretch goals | about $7–8 per endpoint per AZ per month |
| CloudTrail | 1 management trail + vault data events | Low at synthetic volumes |
| Logs, Flow Logs | Short retention | Low |
| Public IPv4 on EC2 | 1 address | about $3.60 per month |

Deploy, capture evidence, then `terraform destroy`.

---

## 7. Documentation (GitHub deliverables)

- **README.md:** purpose, diagram, the "what I built" statement, controls summary, deploy/destroy steps, cost notes, links to evidence.
- **docs/architecture.md:** diagram plus data flows.
- **docs/threat-model.md:** STRIDE analysis for each component, mapped to the controls.
- **docs/data-classification.md:** what counts as PHI, where it may live, and where it must never appear.
- **docs/ai-security.md:** the AI design and OWASP LLM mapping.
- **docs/adr/:** one record per significant decision.
- **docs/runbooks/:** one response runbook per CloudWatch alarm.
- **docs/evidence/:** screenshots and CLI output for every check in §9.

---

## 8. Phased roadmap

| Phase | Deliverable | Status |
|---|---|---|
| 0. Design | Diagram, threat model, data classification, first ADRs, repo skeleton | Done |
| 1. Bootstrap | Remote state (encrypted S3 with native locking), GitHub OIDC role, account budget (ADR-0011) | Done |
| 2. Network | VPC, subnets, routing, S3 gateway endpoint (data-perimeter policy, ADR-0012), Flow Logs; the `davicare-logs` key is created here because Flow Logs need it | Code ready |
| 3. Security core | KMS keys, IAM roles and boundary, security groups, Access Analyzer | |
| 4. Data | RDS MySQL (private, encrypted, TLS) and the hardened S3 vault | |
| 5. Compute + thin app | EC2 (SSM, IMDSv2) running FastAPI, with synthetic data loaded | |
| 6. Monitoring | CloudTrail, metric filters, alarms, SNS, Budgets, app audit logs | |
| 7. AI foundation | `docs/ai-security.md` and the disabled `ai_foundation` module | |
| 8. CI + evidence | GitHub Actions scans, evidence capture, runbooks, README polish | |

---

## 9. Verification (evidence for every claim)

- **IaC quality:** `terraform fmt`, `validate` and `plan` pass in CI. Checkov and Trivy report no unaddressed high findings; each exception is justified in an ADR. Gitleaks finds no secrets.
- **Segmentation:** RDS has no public endpoint and a connection from the internet times out. Port 22 is refused. An SSM session works.
- **Least privilege:** from EC2, reading another bucket or prefix, using another KMS key, or reading another secret each return `AccessDenied`, visible in CloudTrail. The app DB user can't run DROP or ALTER.
- **Encryption:** CLI output shows KMS on RDS, S3, EBS and the log groups. An upload without SSE-KMS and a non-TLS request to S3 are both rejected. A non-TLS MySQL connection is refused.
- **Storage:** making the bucket or an object public is blocked. Access from outside the VPC endpoint is denied. Earlier object versions are kept.
- **Monitoring:** simulated events (SG change, IAM policy change, KMS key disable, a burst of AccessDenied errors) trigger alarms and the SNS email. Screenshots saved in `docs/evidence/`.
- **Teardown:** `terraform destroy` removes everything, and a follow-up check confirms no billable resources are left.

---

## Deferred

- Real PHI and a BAA
- A fixed budget
- A custom domain
- GuardDuty, Security Hub and AWS Config (candidates once there's a budget)
- AI work beyond the stretch goal
