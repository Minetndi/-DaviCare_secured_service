# davicare-logs (ADR-0005): encrypts log groups now; CloudTrail is added in
# Phase 6. Created early because VPC Flow Logs (Phase 2) need it.
resource "aws_kms_key" "logs" {
  description             = "davicare-logs: CloudWatch Logs, Flow Logs, CloudTrail"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.logs_key.json
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

data "aws_iam_policy_document" "logs_key" {
  # Root statement delegates to IAM and keeps a recovery path (ADR-0005).
  # Phase 3 narrows administration to the break-glass role.
  statement {
    sid       = "AccountRootAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  # CloudWatch Logs may use the key only for this project's log groups.
  statement {
    sid = "CloudWatchLogsDavicareGroups"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/davicare/*"]
    }
  }
}
