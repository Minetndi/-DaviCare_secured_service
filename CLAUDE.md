# DaviCare Secure Medical Data Vault

Cloud-security portfolio project: a secure healthcare data environment on AWS, built with Terraform. The app is deliberately thin; it exists to generate realistic access and logs for the security controls. **All data is synthetic.**

- Design and phases: `docs/project-plan.md` (the source of truth for *what* to build)
- Build sequence for the remaining phases: `docs/implementation-plan.md` (the source of truth for *how/when*)
- Decisions: `docs/adr/` (read the relevant ADR before changing a control it covers)

## Environment

- AWS account `982911860764`, region `us-east-1`, name prefix `davicare-dev`.
- Remote state: `davicare-tfstate-982911860764-us-east-1`, key `envs/dev/terraform.tfstate`, S3-native locking (ADR-0008).
- `infra/bootstrap/` uses **local** state and is applied once; never destroy it as part of a teardown.
- Windows host (`C:/Users/Minet/onedrive/documents/repos/davicare-cure-vault` on the build machine). Use the Bash tool (Git Bash) with forward slashes; PowerShell is also available.
- Required tools: Terraform >= 1.10, AWS CLI v2, Session Manager plugin, Python 3.11+, `gh` (with `workflow` scope for Phase 8). Optional locally: checkov, trivy, gitleaks.

## Layout

```
infra/bootstrap/        state bucket + key, GitHub OIDC plan-only CI role, budget (local state)
infra/modules/<name>/   network, security, storage, database, compute, monitoring, ai_foundation
infra/envs/dev/         root module: wires modules, default tags, backend
app/                    FastAPI app (thin)
scripts/                synthetic data generator, DB setup, verification scripts
docs/                   plan, architecture, threat model, data classification, ai-security, adr/, runbooks/, evidence/
.github/workflows/      fmt/validate/plan, Checkov, Trivy, gitleaks
```

## Terraform conventions

Match the existing modules:

- Each module has `versions.tf` (TF `>= 1.10`, `hashicorp/aws ~> 6.0`, plus the `account_id`/`partition`/`region` locals), `variables.tf`, `outputs.tf`, and one file per concern (`kms.tf`, `vpc.tf`, ...).
- Policies are written with `data "aws_iam_policy_document"`, never inline JSON strings. Every statement has a `sid` where it helps the evidence.
- Resource names use `var.name` (`"${var.name}-..."`); Terraform resource labels are short (`this`, `logs`, `data`).
- Log groups live under `/davicare/${var.name}/...` (the logs key only allows `/davicare/*`), are KMS-encrypted with `davicare-logs`, and use `var.log_retention_days`.
- Tags come from `default_tags` in `envs/dev/versions.tf`; only add `Name` tags.
- Short comments explain *why*, and cite the ADR (`# ... (ADR-0012)`). No comments restating the code.
- Run `terraform fmt -recursive infra` and `terraform validate` before every commit.

## Security invariants (never break these without a new ADR)

- No `*` actions or `*` resources in app/workload IAM policies (key policies' `resources = ["*"]` is the normal KMS form). The app role carries the permissions boundary.
- No IAM user access keys, no SSH (no port 22, no key pair), IMDSv2 required.
- No secrets in Terraform variables, `user_data`, state, Git or logs. RDS manages the master password; the app DB password is written to Secrets Manager by the setup script, not by Terraform.
- No NAT Gateway; private route tables have no internet route.
- Every S3 bucket: Block Public Access, `BucketOwnerEnforced`, SSE-KMS, TLS-only policy. The vault also requires the data key and the VPC endpoint (break-glass excepted).
- No PHI (real or synthetic record fields) in logs, metrics, tags, names or evidence. Audit logs carry user, action, record ID and time only.
- Cost: no interface endpoints, ALB, Multi-AZ, GuardDuty/Security Hub/Config unless the user approves; AI foundation stays `enable_ai_foundation = false`.

## Workflow

- One branch per unit of work (`phase-N-<name>`), one PR, the **user merges** on GitHub. Don't merge or push to `main`.
- **The user runs `terraform apply` and `destroy`** (the permission guard blocks Claude). Claude runs `fmt`, `validate`, `plan -out tfplan` and read-only AWS CLI checks, then hands over the exact apply command.
- After an apply: verify every control, record results in `docs/evidence/phase-N-<name>.md` (same table format as `phase-1-bootstrap.md`: Check | Command | Result, with refused requests shown in bold), update the status in `README.md` and `docs/project-plan.md` §8.
- New design decisions get an ADR (copy `docs/adr/0000-template.md`, add it to `docs/adr/README.md`).
- Docs style: plain English, short sentences, tables for comparisons, no marketing language.
- Deploy → capture evidence → `terraform destroy` in `envs/dev` to keep costs low.

## Common commands

```sh
terraform -chdir=infra/envs/dev init
terraform fmt -recursive infra
terraform -chdir=infra/envs/dev validate
terraform -chdir=infra/envs/dev plan -out tfplan
# user only:
terraform -chdir=infra/envs/dev apply tfplan
terraform -chdir=infra/envs/dev destroy
```
