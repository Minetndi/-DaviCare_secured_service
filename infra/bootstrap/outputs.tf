output "state_bucket" {
  description = "S3 bucket holding remote state for the other stacks."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_kms_key_arn" {
  description = "KMS key that encrypts remote state."
  value       = aws_kms_key.tfstate.arn
}

output "ci_role_arn" {
  description = "Role GitHub Actions assumes via OIDC (set as the AWS_CI_ROLE_ARN repo variable)."
  value       = aws_iam_role.ci.arn
}

output "backend_config" {
  description = "Backend block for envs/dev."
  value       = <<-EOT
    backend "s3" {
      bucket       = "${aws_s3_bucket.tfstate.bucket}"
      key          = "envs/dev/terraform.tfstate"
      region       = "${var.region}"
      encrypt      = true
      kms_key_id   = "${aws_kms_key.tfstate.arn}"
      use_lockfile = true
    }
  EOT
}
