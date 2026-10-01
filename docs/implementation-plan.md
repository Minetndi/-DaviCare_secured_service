# Implementation Plan: Phases 2 (finish) to 8

This is the build sequence for everything left in [project-plan.md](project-plan.md) §8. The project plan says *what* to build. This document says *how and in what order*, who does each step, and how each control is proved.

**Approach: build once, apply once.** All the Terraform and app code for Phases 3–8 goes on one branch, with one commit per phase so each phase can be reviewed on its own. It is applied to AWS in one `terraform apply`. Then every control is checked at the same time, evidence is written for each phase, and the environment is torn down.

---

## 1. Current state (2026-10-01)

| Phase | Code | On `main` | In AWS |
|---|---|---|---|
| 0. Design | Done | Yes | n/a |
| 1. Bootstrap | Done | Yes (PRs #1, #2) | Applied and verified |
| 2. Network | Done | Yes (PR #3) | **Unconfirmed.** No evidence file yet |
| 3–8 | Not started | n/a | n/a |

---

## 2. Prerequisites (checked on the machine that runs the build)

| # | Item | Why | Check (install if missing) |
|---|---|---|---|
| P1 | Terraform >= 1.10 | Everything | `terraform version` (`winget install Hashicorp.Terraform`) |
| P2 | AWS CLI v2 with credentials for account 982911860764 | Plans, verification and evidence | `aws sts get-caller-identity` (`winget install Amazon.AWSCLI`) |
| P3 | Session Manager plugin | SSM shell and port forwarding to RDS | `session-manager-plugin --version` (`winget install Amazon.SessionManagerPlugin`) |
| P4 | `envs/dev` initialised against the remote state | Plans | `terraform -chdir=infra/envs/dev init` succeeds |
| P5 | Python 3.11+ with `venv` | App tests, data generator, DB setup script | `python --version` |
| P6 | `gh` logged in with the `workflow` scope | Pushing `.github/workflows/*` | `gh auth status` shows `workflow` (`gh auth refresh -s workflow`) |
| P7 | MFA on the human IAM identity | Break-glass and auditor roles require MFA | IAM console → Security credentials → Assign MFA |
| P8 | Plan to leave access keys behind | The design forbids long-lived keys | Stage 6: IAM Identity Center user with MFA, then delete the access key |
| P9 | Bootstrap state backup | `infra/bootstrap/terraform.tfstate` is local and gitignored | Copy it to a password manager or another safe place |
| P10 | Alert email | SNS alarm subscription (Phase 6) | Same address as the budget email unless the user says otherwise |

---

## 3. Decisions taken in this plan (change any before Stage 1)

| # | Decision | Default | Reason |
|---|---|---|---|
| D1 | Who may reach HTTPS 443 on EC2 | `allowed_ingress_cidrs` = **your public IP /32** | The project plan says 443 is open, but there's no reason to expose a vault demo to the whole internet. 0.0.0.0/0 is a one-line change |
| D2 | App DB user privileges | **`SELECT, INSERT`** on `davicare.*`, `REQUIRE SSL` | The plan says SELECT/INSERT; ADR-0009 says SELECT/INSERT/UPDATE. The app never updates rows, so ADR-0009 gets corrected |
| D3 | MySQL version | **8.4** (not 8.0) | RDS MySQL 8.0 left standard support on 2026-07-31; running it now adds Extended Support charges. ADR-0006 is updated |
| D4 | Instance type | **t4g.micro**, Amazon Linux 2023 arm64 | Cheapest Graviton option; matches db.t4g.micro |
| D5 | How the app identifies callers | **Two demo API keys** (`clinician`, `auditor`), hashed, kept in the app secret | The audit log must say *who*. Users and logins are outside the scope of this project |
| D6 | How app code reaches EC2 | Terraform zips `app/` into a private **artifacts bucket**; `user_data` downloads it through the S3 endpoint | No secrets in `user_data`, no Git credentials on the box, and the code stays separate from the PHI vault |
| D7 | How the DB user is created | `scripts/db_setup.py` runs **on your machine** through an **SSM port-forward** to RDS, using the master secret, which only you can read | EC2 never sees the master password (ADR-0009). The script generates the app password and writes it straight to Secrets Manager, so it never enters Terraform state |
| D8 | Human access after the build | **IAM Identity Center** user with MFA, then delete the IAM user's access key | Assuming a role needs base credentials; Identity Center gives short-lived ones for free |
| D9 | Dev teardown settings | `force_destroy` on buckets, `skip_final_snapshot`, secrets with `recovery_window_in_days = 0`, `deletion_protection` set by a variable | So `terraform destroy` actually finishes. Recorded in an ADR |
| D10 | Branching | One branch `phases-3-8`, one commit per phase, one PR; evidence in a follow-up PR `phases-2-8-evidence` | Matches "build once, apply once" and keeps reviewable units |

---

## 4. Cross-cutting design notes

- **Avoiding module cycles.** The vault bucket name is computed once in `envs/dev` (`davicare-dev-vault-<account>`) and passed to both `security` (the data key policy) and `storage`. The app role's scoped policy is attached in `compute`, where the vault, artifact and secret ARNs are all known. `security` only creates the role, the instance profile and the permissions boundary.
- **Network ↔ security.** `security` takes `vpc_id` from `network` for the security groups, and `network` takes the logs key from `security`. Terraform resolves dependencies per value, so this isn't a cycle. If it ever becomes one, the security groups move to their own `sg.tf` in `envs/dev`.
- **Vault deny vs. Terraform.** The VPC-endpoint-only deny covers **object** actions only (`s3:GetObject`, `PutObject`, `DeleteObject*`, `ListBucket*`), so Terraform can still manage bucket configuration from your laptop. `vault_admin_principal_arns` (break-glass role plus whoever runs Terraform) is excepted, so `force_destroy` can empty the bucket during teardown.
- **Server access log bucket uses SSE-S3.** S3 server access logging can't deliver to a bucket whose default encryption is SSE-KMS. This is the one bucket without a CMK, which is recorded in an ADR and the Checkov exception list.
- **SNS encryption.** CloudWatch alarms can't publish to a topic encrypted with `aws/sns`, so the topic uses `davicare-logs` with a key statement for `cloudwatch.amazonaws.com`.
- **The one `*` resource exception.** `AmazonSSMManagedInstanceCore` (AWS-managed) uses `Resource: *`. The boundary still caps it, and the ADR records it.

---

## 5. Work breakdown by phase

Each phase lists files, resources, details, and the checks that become evidence.

### Phase 2 – Network (finish)

- **Code:** none.
- **Apply:** applied together with everything else in Stage 2. If Phase 2 is already in AWS, the plan simply won't show those 21 resources.
- **Evidence (`docs/evidence/phase-2-network.md`):**

| Check | Command |
|---|---|
| Private route table has no `0.0.0.0/0` route | `aws ec2 describe-route-tables` |
| Public subnets don't auto-assign public IPs | `aws ec2 describe-subnets --query ...MapPublicIpOnLaunch` |
| Default SG has no rules | `aws ec2 describe-security-groups --filters group-name=default` |
| Private NACL allows only 10.0.0.0/16 | `aws ec2 describe-network-acls` |
| Flow logs arriving and encrypted | `aws logs describe-log-groups` (kmsKeyId), `aws logs filter-log-events` |
| Flow logs role trust is scoped | `aws iam get-role` |
| **Endpoint blocks a bucket in another account** | From EC2 (Phase 5): `aws s3 ls s3://<public-aws-sample-bucket>` → AccessDenied |

### Phase 3 – Security core (`infra/modules/security`)

| File | Contents |
|---|---|
| `kms.tf` | **`davicare-data` key** + alias, rotation, 30-day window. Policy: root admin; break-glass key administration; app role `Decrypt`/`GenerateDataKey` only with `kms:ViaService` = `s3.us-east-1` or `secretsmanager.us-east-1`. **`davicare-logs` key**: add a CloudTrail statement (`GenerateDataKey*`, scoped by `aws:cloudtrail:arn` encryption context and `aws:SourceArn`), a `cloudwatch.amazonaws.com` statement for SNS, and account-principal decrypt of CloudTrail logs |
| `iam_app.tf` | `davicare-dev-app` role (EC2 trust, `aws:SourceAccount`), instance profile, **permissions boundary** policy (max allowed: vault `records/*` Get/Put, artifact object Get, data key via S3/Secrets Manager, app secret, `/davicare/*` logs, SSM core actions; explicit deny on `iam:*`, `kms:Disable*`/`ScheduleKeyDeletion`, `s3:PutBucketPolicy`, `cloudtrail:*`), and attachment of `AmazonSSMManagedInstanceCore` |
| `iam_humans.tf` | **`davicare-break-glass`**: trusts the account with `aws:MultiFactorAuthPresent = true` and `MultiFactorAuthAge < 3600`, `AdministratorAccess`, one-hour sessions. **`davicare-auditor`**: same MFA trust, `SecurityAudit` + `ViewOnlyAccess`, so it can read config but not object data |
| `sg.tf` | **`app` SG**: in 443 from `allowed_ingress_cidrs`; out 443 to 0.0.0.0/0 (SSM, Secrets Manager, Logs, PyPI, S3 via endpoint), out 3306 to `db` SG. **`db` SG**: in 3306 from `app` SG only, **no egress**. Written with `aws_vpc_security_group_ingress_rule` and `_egress_rule` resources |
| `access_analyzer.tf` | `aws_accessanalyzer_analyzer`, type `ACCOUNT` (free). Unused-access analyzer off (paid) |
| `variables.tf` / `outputs.tf` | Inputs: `vpc_id`, `allowed_ingress_cidrs`, `vault_bucket_name`. Outputs: key ARNs, role and profile names and ARNs, SG IDs, boundary ARN |

**Evidence (`phase-3-security.md`):**
- both keys have rotation on, and their policies are shown
- the boundary is attached to the app role
- the app policies have no `*` (`aws iam get-role-policy`, plus a grep check)
- break-glass refuses assumption without MFA: **AccessDenied**
- the SG rules are exactly the chain described above
- Access Analyzer is active and lists 0 findings, or explains any it has

### Phase 4 – Data (`infra/modules/storage`, `infra/modules/database`)

**storage**

| Resource | Details |
|---|---|
| Vault `davicare-dev-vault-<account>` | BPA (bucket level), `BucketOwnerEnforced`, versioning, SSE-KMS default with data key and bucket key, access logging to the log bucket, lifecycle (noncurrent versions expire after 30 days, incomplete multipart uploads aborted after 7 days), `force_destroy` |
| Vault policy | `DenyInsecureTransport`; `DenyNonKmsPut`; `DenyWrongKmsKey`; `DenyOutsideVpce` (object actions, `aws:SourceVpce` ≠ endpoint, `aws:PrincipalArn` not in admin list) |
| Access-log bucket | BPA, `BucketOwnerEnforced`, SSE-S3 (see §4), TLS-only, policy allowing only `logging.s3.amazonaws.com` with `aws:SourceArn` = vault and `aws:SourceAccount`, 90-day expiry |
| Artifacts bucket | Same hardening as the vault (data key, TLS-only); holds `app.zip` only |
| Account-level BPA | `aws_s3_account_public_access_block`, all four settings on. Terraform removes it on destroy, so the teardown evidence notes it and you can turn it back on by hand |

**database**

| Resource | Details |
|---|---|
| `aws_db_subnet_group` | the two private subnets |
| `aws_db_parameter_group` (mysql8.4) | `require_secure_transport = 1` |
| `aws_db_instance` | MySQL 8.4, db.t4g.micro, 20 GB gp3, `storage_encrypted` with the data key, `publicly_accessible = false`, `db` SG, `manage_master_user_password` with the master secret encrypted by the data key, 7-day encrypted backups, `deletion_protection = var.deletion_protection`, `skip_final_snapshot = true`, `ca_cert_identifier = rds-ca-rsa2048-g1`, auto minor upgrades, Performance Insights off |
| App secret `davicare-dev/app` | `aws_secretsmanager_secret` encrypted with the data key, **with no version**: `db_setup.py` writes the value. Recovery window 0 |

**Evidence (`phase-4-data.md`):**
- RDS: `PubliclyAccessible=false`, `StorageEncrypted` with the data key, parameter `require_secure_transport=ON`
- **a TCP connection to the RDS endpoint from the internet times out**
- **a non-TLS MySQL connection is refused**
- **`DROP TABLE` as `davicare_app` fails**
- vault: BPA, ownership, versioning, encryption, policy
- **an upload without SSE-KMS is denied**
- **an upload with another key is denied**
- **an HTTP (non-TLS) request is denied**
- **a GET from outside the VPC, as a non-admin principal, is denied**
- **`put-bucket-acl public-read` and a public bucket policy are blocked**
- an earlier object version is still there after an overwrite

### Phase 5 – Compute + thin app (`infra/modules/compute`, `app/`, `scripts/`)

**compute**

| Resource | Details |
|---|---|
| `aws_instance` | AL2023 arm64 AMI from the SSM public parameter, t4g.micro, public subnet A, public IP on, **no key pair**, `http_tokens = required`, hop limit 1, root gp3 8 GB encrypted with the data key, `user_data_replace_on_change` |
| `aws_iam_role_policy` (app scoped) | `s3:GetObject`/`PutObject` on `vault/records/*`; `s3:GetObject` on `artifacts/app.zip`; `kms:Decrypt`/`GenerateDataKey` on the data key with `kms:ViaService`; `secretsmanager:GetSecretValue` on the app secret ARN; `logs:CreateLogStream`/`PutLogEvents` on its own log groups |
| Log groups | `/davicare/davicare-dev/app` and `/davicare/davicare-dev/ssm-sessions`, both using the logs key |
| SSM session preferences | `SSM-SessionManagerRunShell` document: sessions logged to the encrypted log group, idle timeout 20 minutes |
| `archive_file` + `aws_s3_object` | `app/` → `app.zip` in the artifacts bucket. Its hash feeds `user_data`, so a code change replaces the instance |
| `user_data` (template) | install python3.11 → create `davicare` system user → download the zip through the endpoint → venv and `pip install` → fetch the RDS CA bundle → generate a self-signed cert → systemd unit running uvicorn on 443 as a non-root user with `CAP_NET_BIND_SERVICE`. **Contains no secrets** |

**app/** (FastAPI; Python 3.11)

```
app/
  davicare_app/
    main.py        routes, size limits, error handling (no stack traces to clients)
    config.py      env vars: region, vault bucket, secret id, log group (no secrets)
    secrets.py     fetches the app secret once, caches it with a TTL
    auth.py        API key → user (hashed compare, constant time)
    db.py          PyMySQL, ssl={"ca": rds-ca bundle, verify}, parameterized queries only
    storage.py     S3 streaming upload/download, SSE-KMS with the data key, key prefix records/
    audit.py       JSON audit events {ts, user, action, record_id, outcome}, no PHI fields
    models.py      Pydantic models; `synthetic: true` required
  tests/           pytest: auth, audit has no PHI, SQL uses parameters, size limit
  requirements.txt (pinned)
```

Endpoints: `GET /health`, `POST /patients`, `GET /patients/{id}`, `POST /patients/{id}/documents` (5 MB limit), `GET /documents/{id}`. Swagger UI only; no Next.js page (dropped first under the plan's rule).

**scripts/**

| Script | Purpose |
|---|---|
| `db_setup.py` | Run locally through `aws ssm start-session --document-name AWS-StartPortForwardingSessionToRemoteHost`. Reads the master secret, creates the `davicare` schema and tables, creates `davicare_app` (`SELECT, INSERT`, `REQUIRE SSL`), generates its password and two API keys, writes them to the app secret, and prints only the API keys |
| `generate_synthetic.py` | Faker-based mothers and children, with every record marked `SYNTHETIC`; output goes to `scripts/output/` (gitignored) |
| `load_synthetic.py` | Posts records and a few dummy documents **through the API**, so the audit log records the load |
| `verify/*.sh` | One script per evidence area, which prints the commands and results for the evidence tables |

**Evidence (`phase-5-compute.md`):**
- IMDSv2 required; IMDSv1 call **fails**
- no key pair; **port 22 refused or timed out**
- an SSM session works and is logged
- EBS encrypted with the data key
- HTTPS health check from your IP returns 200, and **from another IP it times out**
- **from EC2: another prefix, another bucket, another secret (the master secret) and another key all return AccessDenied**, and those denials show in CloudTrail
- app audit log entries contain no PHI
- the endpoint blocks another account's bucket (the Phase 2 check)

### Phase 6 – Monitoring (`infra/modules/monitoring`)

| Resource | Details |
|---|---|
| CloudTrail bucket | SSE-KMS (logs key), BPA, ownership enforced, TLS-only, policy allowing only `cloudtrail.amazonaws.com` with `aws:SourceArn` = the trail, 90-day expiry, `force_destroy` |
| `aws_cloudtrail` | multi-region, global service events, log file validation, KMS logs key, CloudWatch Logs integration (`/davicare/davicare-dev/cloudtrail` and a delivery role), advanced event selectors: all management events + **S3 data events on the vault only** |
| SNS topic `davicare-dev-alerts` | logs key, topic policy allowing only `cloudwatch.amazonaws.com` from this account, email subscription (`alert_email`) |
| Metric filters + alarms (namespace `DaviCare/Security`) | root account use; IAM policy changes; SG changes; NACL/route table changes; KMS disable or scheduled deletion; S3 bucket policy changes; console login without MFA; console sign-in failures; ≥ 5 `AccessDenied`/`UnauthorizedOperation` in 5 minutes; CloudTrail config changes |
| RDS alarms | CPU > 80% for 10 minutes; `DatabaseConnections` > 20 |

The budget already exists in bootstrap (ADR-0011).

**Evidence (`phase-6-monitoring.md`):**
- trail status: logging, multi-region, validation on
- `aws cloudtrail validate-logs` passes
- vault data events are visible
- **simulated events**: add and remove an SG rule; attach and detach a dummy policy; schedule then cancel a KMS key deletion on a throwaway key; a burst of AccessDenied errors. Each triggers its alarm (`describe-alarm-history`) and an SNS email, with screenshots from you

### Phase 7 – AI foundation (`docs/ai-security.md`, `infra/modules/ai_foundation`)

- **Module.** Every resource has `count = var.enable_ai_foundation ? 1 : 0`, and the default is `false`:
  - Bedrock Runtime interface endpoint in the private subnets, with an SG allowing 443 from the app SG only
  - an endpoint policy allowing only the `ai-invoker` role
  - an `ai-invoker` role that the app role may assume (granted only when the flag is on), with `bedrock:InvokeModel` on `approved_model_arns` and an explicit deny on everything else
  - a Bedrock Guardrail: PII entities masked or blocked, a prompt-attack filter at HIGH, and denied topics (diagnosis, dosage)
  - model invocation logging to `/davicare/davicare-dev/bedrock-invocations` (logs key)
- **Docs.** `docs/ai-security.md` covers the data flow, the controls, and a mapping table to the OWASP Top 10 for LLM Applications (2025), plus residual risks.
- **Evidence (`phase-7-ai.md`):** `terraform plan` shows 0 AI resources with the flag off, and `terraform validate`/`plan -var enable_ai_foundation=true` succeed (planned, **not applied**). The stretch goal of a live endpoint is out of scope unless you ask for it.

### Phase 8 – CI, docs, evidence, teardown

| Item | Details |
|---|---|
| `.github/workflows/terraform.yml` | On PR and push to main: `fmt -check`; `validate` for bootstrap, dev, and each module; `plan` for `envs/dev` through OIDC (`AWS_CI_ROLE_ARN`, plan-only role); plan summary in the job summary. Permissions `id-token: write`, `contents: read`. Actions pinned by SHA |
| `.github/workflows/security.yml` | Checkov (`.checkov.yaml`, every skip names its ADR), Trivy `config` (HIGH/CRITICAL fail), gitleaks (full history) |
| Runbooks | `docs/runbooks/<alarm>.md` for each alarm in Phase 6: what fired, triage queries (CloudTrail Lake not used; Logs Insights queries given), containment, recovery, evidence to keep |
| README | status table, deploy/destroy steps (the section currently says "To be written"), cost notes, evidence links |
| Docs updates | `architecture.md` (artifacts bucket, SSM port-forward, SNS); `threat-model.md` residual risks; `data-classification.md` (where app audit logs live); `project-plan.md` §8 statuses |
| Teardown | Set `deletion_protection=false` → apply → `terraform destroy` → check that the tagging API shows no `Project=davicare-secure-vault` resources outside bootstrap; KMS keys are pending deletion; Cost Explorer next day. Recorded in `phase-8-teardown.md` |

### New and updated ADRs

| ADR | Title |
|---|---|
| 0013 | Human access: IAM Identity Center, MFA break-glass and auditor roles |
| 0014 | App role permissions boundary and the SSM managed-policy exception |
| 0015 | HTTPS ingress limited to an admin CIDR |
| 0016 | Bootstrapping the app DB user over an SSM port-forward |
| 0017 | Delivering app code from a private artifacts bucket |
| 0018 | Access-log bucket uses SSE-S3 |
| 0019 | Alerting: CloudTrail metric filters to a KMS-encrypted SNS topic |
| 0020 | AI foundation: private Bedrock path, invoker role, Guardrails (off by default) |
| 0021 | Scanner exceptions (Checkov/Trivy) |
| 0022 | Dev-only teardown settings |
| Updated | 0006 (MySQL 8.4), 0009 (SELECT, INSERT only) |

---

## 6. Execution sequence

| Stage | Who | Steps | Done when |
|---|---|---|---|
| **0. Prerequisites** | You | P1–P10 | `terraform version`, `aws sts get-caller-identity` and `session-manager-plugin` all work here |
| **1. Build** | Claude | Branch `phases-3-8` → commit Phase 3, 4, 5, 6, 7, 8 (code + docs + ADRs) → run `fmt`/`validate` after each commit → app unit tests → `terraform plan -out tfplan` → push and open the PR | Clean plan; summary of resource counts and the estimated monthly cost |
| **2. Apply** | You | Review and merge the PR → `terraform -chdir=infra/envs/dev apply tfplan` (Claude regenerates the plan if it's stale) | Apply completes |
| **3. Post-apply setup** | You (Claude gives exact commands) | Confirm the SNS email → open the SSM port-forward → run `db_setup.py` → restart the app over SSM → run `generate_synthetic.py` + `load_synthetic.py` | `/health` is 200, and records and documents exist |
| **4. Verify and evidence** | Claude (and you for screenshots) | Run `scripts/verify/*` → write `docs/evidence/phase-2…7` → trigger the alarm simulations → you save the SNS email screenshots | Every check in project plan §9 has a result |
| **5. CI** | Claude, then you | Watch the workflows run on the PR → fix findings or add ADR-justified skips | All workflows green |
| **6. Human access** | You | Enable IAM Identity Center, create your user with MFA → test assuming break-glass → **delete the IAM user access key** → re-run `aws sts get-caller-identity` through SSO | No active access keys (`aws iam list-access-keys`) |
| **7. Teardown** | You (Claude verifies) | `deletion_protection=false` apply → `destroy` → Claude runs the leftover check | Nothing billable left except bootstrap |
| **8. Close-out** | Claude, then you | Evidence PR (`phases-2-8-evidence`), README and status updates → you merge | All phases marked Done |

---

## 7. Cost while deployed (us-east-1, without free tier)

| Item | ~USD / month |
|---|---|
| RDS db.t4g.micro + 20 GB gp3 + backups | 14 |
| EC2 t4g.micro + 8 GB gp3 | 7 |
| Public IPv4 | 3.60 |
| KMS: data + logs (tfstate is already paid for) | 2 |
| Secrets Manager: master + app | 0.80 |
| CloudWatch alarms (~12) + logs | 1.50 |
| CloudTrail data events, S3, SNS | < 1 |
| **Total** | **~30** |

That is above the $20 budget for a full month, so the plan is to **deploy for about 3–5 days** (~$4–5) and then tear down. The budget emails at 50%, which is your early warning.

---

## 8. Risks and how they're handled

| Risk | Handling |
|---|---|
| Vault policy locks out Terraform or teardown | Object-only deny with an admin principal exception (§4); tested in Stage 4 before teardown |
| Access Analyzer or CloudTrail already exist in the account | Read-only check in Stage 1; import or reuse instead of duplicating (a second trail with management events costs money) |
| `user_data` fails silently | `cloud-init` output is read over SSM; health check in Stage 3 |
| An AWS-owned bucket name changes and package installs break (ADR-0012) | Add the new bucket to the endpoint policy; documented in a runbook |
| Stale saved plan | Re-run `plan -out tfplan` just before apply |
| Account-level BPA is removed at destroy | Called out in the teardown evidence; re-enabled by hand if wanted |
| Monthly cost overrun | Short deploy window, budget alerts, teardown check |

---

## 9. Definition of done

- Every row in project plan §9 has evidence in `docs/evidence/`, with every **refused** request shown.
- CI (fmt, validate, plan, Checkov, Trivy, gitleaks) is green on `main`, and every exception is justified in ADR-0021.
- README, architecture, threat model, data classification, ai-security, ADRs 0013–0022 and runbooks are complete.
- No IAM user access keys remain. The environment is destroyed, with only bootstrap left.
- Project plan §8 shows every phase as Done.
