# Bootstrap stack

Creates the shared, long-lived pieces that every other stack depends on. It runs once, from a workstation, with **local** state (ADR-0008, ADR-0011).

| Resource | Purpose |
|---|---|
| `davicare-tfstate-<account>-<region>` S3 bucket | Remote state: SSE-KMS, versioning, Block Public Access, ACLs disabled, TLS-only, wrong-key uploads denied, old versions expire |
| `alias/davicare-tfstate` KMS key | Encrypts state; rotation on |
| GitHub OIDC provider + `davicare-ci` role | Plan-only CI with no access keys; trusted for this repo's pull requests and `main` only |
| `davicare-monthly` budget | Emails at 50% actual, 100% forecast, 100% actual |

## Deploy

```sh
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars   # set budget_alert_email
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Then:

1. **Check the budget address.** AWS Budgets emails subscribers directly, with no confirmation step, so a typo fails silently. Check it in the Billing console.
2. **Back up the local state.** `terraform.tfstate` here is gitignored. Keep a copy somewhere safe (a password manager attachment is fine); it holds no secrets, only IDs and ARNs.
3. **Wire up the dev stack** with the `backend_config` output.
4. **Set the CI role** as a GitHub repository variable:
   ```sh
   gh variable set AWS_CI_ROLE_ARN --body "$(terraform output -raw ci_role_arn)"
   ```

## Verify

```sh
BUCKET=$(terraform output -raw state_bucket)
aws s3api get-bucket-encryption       --bucket "$BUCKET"
aws s3api get-bucket-versioning       --bucket "$BUCKET"
aws s3api get-public-access-block     --bucket "$BUCKET"
aws s3api get-bucket-policy           --bucket "$BUCKET" --query Policy --output text
aws kms get-key-rotation-status --key-id alias/davicare-tfstate
# Non-TLS request must fail:
aws s3api list-objects-v2 --bucket "$BUCKET" --endpoint-url http://s3.us-east-1.amazonaws.com
```

## Destroy (only when retiring the whole project)

Destroy every other stack first. Then remove `prevent_destroy` from `state_bucket.tf`, empty the bucket (all versions), and run `terraform destroy`. The KMS key enters its 30-day deletion window.
