# Lifecycle rules for protecting and managing resources

variable "environment" {
  description = "Environment name (e.g., prod, dev, staging)"
  type        = string
  default     = "dev"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# Example 1: Prevent accidental destruction of critical resources
resource "aws_db_instance" "production_db" {
  identifier     = "prod-database"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  # ... other config
  
  lifecycle {
    prevent_destroy = true  # Cannot destroy via Terraform
  }
}

# Example 2: Create before destroy (zero downtime)
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  
  lifecycle {
    create_before_destroy = true  # New instance created before old deleted
  }
}

# Example 3: Ignore specific changes (drift from external changes)
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  
  tags = {
    Name = "app-server"
    # External tools may modify tags
  }
  
  lifecycle {
    ignore_changes = [
      tags,                    # Ignore all tag changes
      user_data,              # Ignore user_data drift
      ami,                    # Don't auto-upgrade AMI
    ]
  }
}

# Example 4: Ignore specific tag keys
resource "aws_autoscaling_group" "web" {
  name                = "web-asg"
  max_size            = 10
  min_size            = 2
  desired_capacity    = 3
  
  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
  
  lifecycle {
    ignore_changes = [
      desired_capacity,  # Auto-scaling changes this
      target_group_arns, # May be modified externally
    ]
  }
}

# Example 5: Replace triggered by another resource
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  security_groups = [aws_security_group.web.id]
  
  lifecycle {
    replace_triggered_by = [
      aws_security_group.web.id,  # Recreate instance if SG changes
    ]
  }
}

resource "aws_security_group" "web" {
  name = "web-sg"
  # ... config
}

# Example 6: Ignore all changes (read-only mode)
resource "aws_s3_bucket" "logs" {
  bucket = "my-logs-bucket"
  
  lifecycle {
    ignore_changes = all  # Treat as read-only
  }
}

# Example 7: Combined lifecycle rules
resource "aws_db_instance" "main" {
  identifier     = "main-db"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  password       = var.db_password
  
  lifecycle {
    # Protect from accidental deletion
    prevent_destroy = true
    
    # Create new before destroying old (for major upgrades)
    create_before_destroy = false
    
    # Ignore password changes (managed outside Terraform)
    ignore_changes = [
      password,
      backup_window,  # AWS may change this
    ]
  }
}

# Example 8: Module with lifecycle rules
module "critical_infrastructure" {
  source = "../../modules/vpc"
  
  cidr_block   = "10.0.0.0/16"
  project_name = "production"
  environment  = "prod"
}

# Add lifecycle to module resources (in module code)
# modules/vpc/main.tf:
# resource "aws_vpc" "main" {
#   cidr_block = var.cidr_block
#   
#   lifecycle {
#     prevent_destroy = var.environment == "prod"
#   }
# }

# Example 9: Conditional lifecycle rules
locals {
  is_production = var.environment == "prod"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = var.instance_type
  
  lifecycle {
    # Only prevent destroy in production
    prevent_destroy = local.is_production
    
    # Create before destroy in production, otherwise just replace
    create_before_destroy = local.is_production
  }
}

# Example 10: Protect specific resources in a module
resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 100
  encrypted         = true
  
  tags = {
    Name = "critical-data"
  }
  
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = true
    
    # Ignore size changes (may be increased manually)
    ignore_changes = [size]
  }
}

# USAGE PATTERNS:

# Pattern 1: Production databases
# - prevent_destroy = true
# - ignore_changes = [password]

# Pattern 2: Auto-scaling groups
# - ignore_changes = [desired_capacity]

# Pattern 3: Zero-downtime deployments
# - create_before_destroy = true

# Pattern 4: Read-only imports
# - ignore_changes = all

# Pattern 5: External tag management
# - ignore_changes = [tags]
