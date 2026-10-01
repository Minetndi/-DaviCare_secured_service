output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (EC2)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (RDS subnet group)."
  value       = aws_subnet.private[*].id
}

output "s3_endpoint_id" {
  description = "S3 gateway endpoint ID, used by the vault bucket's aws:SourceVpce condition."
  value       = aws_vpc_endpoint.s3.id
}

output "flow_log_group_name" {
  description = "CloudWatch log group receiving VPC Flow Logs."
  value       = aws_cloudwatch_log_group.flow_logs.name
}
