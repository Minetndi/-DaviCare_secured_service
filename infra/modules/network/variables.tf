variable "name" {
  description = "Name prefix for network resources, e.g. davicare-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability Zones, one public and one private subnet each."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "The design uses exactly two Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, in the same order as azs."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, in the same order as azs."
  type        = list(string)
}

variable "flow_log_kms_key_arn" {
  description = "KMS key (davicare-logs) that encrypts the flow log group."
  type        = string
}

variable "flow_log_retention_days" {
  description = "How long flow logs are kept in CloudWatch Logs."
  type        = number
  default     = 30
}
