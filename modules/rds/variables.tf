
variable "identifier" {
  description = "The name of the RDS instance"
  type        = string
}

variable "engine" {
  description = "The database engine (postgres, mysql, mariadb, oracle-se2, sqlserver-ex)"
  type        = string
  validation {
    condition = contains(
      ["postgres", "mysql", "mariadb", "oracle-se2", "sqlserver-ex"],
      var.engine
    )
    error_message = "Engine must be a supported AWS RDS engine."
  }
}

variable "engine_version" {
  description = "The engine version (use empty string to omit and get latest available)"
  type        = string
  default     = ""
}

variable "instance_class" {
  description = "The instance type (e.g., db.t3.micro)"
  type        = string
}

variable "allocated_storage" {
  description = "The allocated storage in GiB"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "db_name" {
  description = "The name of the default database"
  type        = string
}

variable "username" {
  description = "The master username"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "The master password (from Terraform Cloud)"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of VPC security group IDs"
  type        = list(string)
  default     = []
}

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "The number of days to retain backups"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "backup_window" {
  description = "The backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "The maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  description = "If the DB instance should have deletion protection enabled"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created"
  type        = bool
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = []
}

variable "monitoring_interval" {
  description = "The interval, in seconds, for monitoring (0, 1, 5, 10, 15, 30, or 60)"
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60 seconds."
  }
}

variable "monitoring_role_arn" {
  description = "ARN of the IAM role for enhanced monitoring (required if monitoring_interval > 0)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
