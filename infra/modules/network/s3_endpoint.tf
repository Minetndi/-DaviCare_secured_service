# Free gateway endpoint on both route tables, so all in-region S3 traffic
# stays on the AWS network and the vault's VPCE-only policy can work (ADR-0002).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]
  policy            = data.aws_iam_policy_document.s3_endpoint.json

  tags = { Name = "${var.name}-s3" }
}

# Data perimeter (ADR-0012): through this endpoint, only buckets owned by this
# account are reachable, plus read-only access to the AWS-owned buckets that
# Amazon Linux package repos and the SSM agent need. Copying data to an
# attacker's bucket from inside the VPC is blocked.
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid       = "OwnAccountBuckets"
    actions   = ["s3:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    sid     = "AwsOwnedReadOnly"
    actions = ["s3:GetObject"]
    resources = [
      "arn:${local.partition}:s3:::al2023-repos-${local.region}-*/*",
      "arn:${local.partition}:s3:::amazonlinux-2-repos-${local.region}/*",
      "arn:${local.partition}:s3:::aws-ssm-${local.region}/*",
      "arn:${local.partition}:s3:::amazon-ssm-${local.region}/*",
      "arn:${local.partition}:s3:::amazon-ssm-packages-${local.region}/*",
      "arn:${local.partition}:s3:::${local.region}-birdwatcher-prod/*",
      "arn:${local.partition}:s3:::aws-ssm-distributor-file-${local.region}/*",
      "arn:${local.partition}:s3:::aws-ssm-document-attachments-${local.region}/*",
      "arn:${local.partition}:s3:::patch-baseline-snapshot-${local.region}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}
