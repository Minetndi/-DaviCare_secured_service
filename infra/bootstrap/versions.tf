terraform {
  # 1.10+ for S3-native state locking (ADR-0008).
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap state stays local: it creates the bucket the other stacks use.
  # terraform.tfstate is gitignored (ADR-0008).
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "davicare-secure-vault"
      Stack       = "bootstrap"
      ManagedBy   = "terraform"
      DataClass   = "confidential"
      Environment = "shared"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}
