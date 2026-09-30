# Dedicated key for Terraform state (ADR-0011). State outlives the dev
# environment, so it can't depend on the davicare-data/logs keys built there.
resource "aws_kms_key" "tfstate" {
  description             = "davicare-tfstate: encrypts Terraform remote state"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.tfstate_key.json
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/davicare-tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

data "aws_iam_policy_document" "tfstate_key" {
  # Root statement delegates key access to IAM policies and keeps a recovery
  # path if a policy mistake would otherwise lock everyone out (ADR-0005).
  statement {
    sid       = "AccountRootAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }
}
