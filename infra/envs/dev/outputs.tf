output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.network.private_subnet_ids
}

output "s3_endpoint_id" {
  description = "S3 gateway endpoint ID."
  value       = module.network.s3_endpoint_id
}

output "flow_log_group_name" {
  description = "VPC Flow Logs log group."
  value       = module.network.flow_log_group_name
}

output "logs_kms_key_arn" {
  description = "davicare-logs key ARN."
  value       = module.security.logs_kms_key_arn
}
