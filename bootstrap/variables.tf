variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "charan"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_prefix))
    error_message = "Project prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "state_bucket_name" {
  description = "Name for the S3 bucket (leave empty for auto-generated name)"
  type        = string
  default     = ""
}

variable "enable_state_locking" {
  description = "Enable DynamoDB for state locking (optional - S3 provides native consistency, DynamoDB adds explicit locking for concurrent operations)"
  type        = bool
  default     = false  # Changed to false - S3 native consistency is sufficient for most cases
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking (only used if enable_state_locking = true)"
  type        = string
  default     = "terraform-locks"
}

variable "enable_dynamodb_pitr" {
  description = "Enable point-in-time recovery for DynamoDB (only used if enable_state_locking = true)"
  type        = bool
  default     = true
}

variable "key_pair_names" {
  description = "List of EC2 key pair names to create"
  type        = list(string)
  default = [
    "project-charan-dev-key",
    "project-charan-staging-key",
    "project-charan-prod-key"
  ]
}

variable "environments" {
  description = "List of environments to create backend configs for"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "enable_logging" {
  description = "Enable access logging for the state bucket"
  type        = bool
  default     = false
}

# Removed: enable_dynamodb_pitr - no longer using DynamoDB
