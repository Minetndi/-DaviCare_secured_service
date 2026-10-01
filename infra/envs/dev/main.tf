data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "security" {
  source = "../../modules/security"

  name = var.name
}

module "network" {
  source = "../../modules/network"

  name                    = var.name
  vpc_cidr                = var.vpc_cidr
  azs                     = local.azs
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  flow_log_kms_key_arn    = module.security.logs_kms_key_arn
  flow_log_retention_days = var.log_retention_days
}
