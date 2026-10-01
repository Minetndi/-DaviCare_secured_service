# Phase 1 evidence: bootstrap stack

- **Date:** 2026-09-30
- **Account:** 982911860764, `us-east-1`
- **Result:** `terraform apply` created 14 resources, 0 changed, 0 destroyed.

| Check | Command | Result |
|---|---|---|
| Default encryption is SSE-KMS with the state key | `aws s3api get-bucket-encryption` | `aws:kms`, key `e8b17dfd-…`, bucket key on, SSE-C blocked |
| Versioning | `aws s3api get-bucket-versioning` | `Enabled` |
| Block Public Access | `aws s3api get-public-access-block` | all four settings `True` |
| ACLs disabled | `aws s3api get-bucket-ownership-controls` | `BucketOwnerEnforced` |
| Key rotation | `aws kms get-key-rotation-status` | `True`, every 365 days |
| Bucket policy statements | `aws s3api get-bucket-policy` | `DenyInsecureTransport`, `DenyWrongKmsKey` |
| **Plain-HTTP request is refused** | `aws s3api list-objects-v2 --endpoint-url http://…` | `AccessDenied … with an explicit deny in a resource-based policy` |
| **Upload under another KMS key is refused** | `aws s3api put-object --ssekms-key-id alias/aws/s3` | `AccessDenied … with an explicit deny in a resource-based policy` |
| CI role trusts only this repo's PRs and `main` | `aws iam get-role --role-name davicare-ci` | `aud = sts.amazonaws.com`; `sub` limited to `repo:Minetndi/-DaviCare_secured_service:pull_request` and `…:ref:refs/heads/main` |
| Budget | `aws budgets describe-budget` | $20.00, monthly |
| Local state stays out of Git | `git check-ignore` | `terraform.tfstate`, `tfplan`, `terraform.tfvars` all ignored |

The two refused requests show the bucket policy denying even the account's own admin user when the request breaks the rules, so these controls don't depend on IAM permissions alone.
