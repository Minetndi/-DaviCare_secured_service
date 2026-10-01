output "logs_kms_key_arn" {
  description = "ARN of the davicare-logs key."
  value       = aws_kms_key.logs.arn
}
