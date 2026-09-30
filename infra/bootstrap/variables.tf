variable "region" {
  description = "AWS region for the state bucket and all DaviCare stacks."
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI role, as owner/name."
  type        = string
  default     = "Minetndi/-DaviCare_secured_service"
}

variable "budget_limit_usd" {
  description = "Monthly cost budget for the whole account, in USD."
  type        = number
  default     = 20
}

variable "budget_alert_email" {
  description = "Email address that receives budget alerts."
  type        = string
}
