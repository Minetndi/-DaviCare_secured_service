terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Values come from the bootstrap stack's backend_config output (ADR-0008).
  backend "s3" {
    bucket       = "davicare-tfstate-982911860764-us-east-1"
    key          = "envs/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:us-east-1:982911860764:key/e8b17dfd-a741-49af-bf8e-374f9e93af75"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "davicare-secure-vault"
      Stack       = "envs/dev"
      Environment = "dev"
      ManagedBy   = "terraform"
      DataClass   = "synthetic"
    }
  }
}
