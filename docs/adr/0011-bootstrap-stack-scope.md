# ADR-0011: Bootstrap stack scope (state key, plan-only CI role, budget)

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

`infra/bootstrap/` runs once, with local state, before any other stack (ADR-0008). Anything in it outlives `terraform destroy` of the dev environment. Three questions had to be settled:

1. Which KMS key encrypts Terraform state? The `davicare-data` and `davicare-logs` keys (ADR-0005) are created in `envs/dev`, which reads its state from this bucket, and they are destroyed with the environment.
2. How much can the GitHub Actions role do?
3. Where does the cost budget live? The plan put it in the monitoring module, but that module is destroyed after each deploy, which is exactly when a leftover resource would go unnoticed.

## Decision

- **A third CMK, `davicare-tfstate`**, with rotation, used only for the state bucket. Its policy has just the account root statement, so access is granted through IAM policies (the CI role's is limited to use via S3 with `kms:ViaService`).
- **The CI role `davicare-ci` is plan-only.** It has `ReadOnlyAccess`, read access to state, write access only to `*.tflock` lock objects, and the state key via S3. It trusts GitHub OIDC tokens for this repository's pull requests and `main` branch only. Applies run locally (deploy, capture evidence, destroy).
- **The account budget moves to bootstrap.** It alerts by email at 50% actual, 100% forecast and 100% actual of a small monthly limit (default $20).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Dedicated state CMK (chosen)** | Independent of the dev lifecycle; state access auditable separately | About $1/month more |
| Reuse `davicare-logs` | No extra key | Circular dependency: the key would live in the state it protects, and be destroyed with the environment |
| SSE-S3 for state | Free | No key policy control; weaker evidence for a security project |
| CI role that can also apply | Full GitOps | A write-capable role reachable from CI; needs branch protection and environments first |
| Budget in `monitoring` | Matches the original plan | Deleted by every teardown |

## Consequences

- Three CMKs in total (about $3/month), not two.
- `ReadOnlyAccess` can read S3 objects in general. The data vault's VPC-endpoint-only bucket policy (Phase 4) still denies the CI role, because CI runs outside the VPC. This is verified in Phase 9 evidence.
- A CI apply role can be added later, trusted only from a protected GitHub environment, with its own ADR.
- The state bucket has `prevent_destroy`. Removing it is a deliberate, manual step (see `infra/bootstrap/README.md`).
