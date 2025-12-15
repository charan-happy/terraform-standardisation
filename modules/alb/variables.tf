variable "name" {
  description = "Name of the load balancer"
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB (minimum 2)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "enable_http2" {
  description = "Enable HTTP/2"
  type        = bool
  default     = true
}

variable "enable_access_logs" {
  description = "Enable access logs"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for access logs"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "S3 prefix for access logs"
  type        = string
  default     = ""
}

variable "target_groups" {
  description = "Map of target group configurations"
  type = map(object({
    port                 = number
    protocol             = string
    deregistration_delay = number
    enable_stickiness    = bool
    stickiness_duration  = number
    health_check = object({
      enabled             = bool
      healthy_threshold   = number
      unhealthy_threshold = number
      timeout             = number
      interval            = number
      path                = string
      matcher             = string
      protocol            = string
    })
  }))
  default = {}
}

variable "target_attachments" {
  description = "Map of instance attachments to target groups"
  type = map(object({
    target_group_key = string
    instance_id      = string
    port             = number
  }))
  default = {}
}

variable "create_http_listener" {
  description = "Create HTTP listener"
  type        = bool
  default     = true
}

variable "create_https_listener" {
  description = "Create HTTPS listener"
  type        = bool
  default     = false
}

variable "redirect_http_to_https" {
  description = "Redirect HTTP to HTTPS"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS"
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "default_target_group_key" {
  description = "Key of the default target group"
  type        = string
}

variable "listener_rules" {
  description = "Map of listener rules for path-based routing"
  type = map(object({
    priority         = number
    target_group_key = string
    path_patterns    = optional(list(string))
    host_headers     = optional(list(string))
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
