# Database Layer - RDS, Security Groups
# Changes less frequently than compute

terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket  = "terraform-state-charan-492267476800"
    key     = "project-charan/dev/database/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Database"
    }
  }
}

# Read networking outputs
data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "terraform-state-charan-492267476800"
    key    = "project-charan/dev/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

# Database Security Group
module "db_security_group" {
  source = "../../../../modules/security-groups"

  name        = "${var.project_name}-db-sg"
  description = "Security group for RDS database"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  ingress_rules = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_ipv4   = data.terraform_remote_state.networking.outputs.vpc_cidr
      description = "PostgreSQL from VPC"
    }
  ]

  tags = {
    Purpose = "Database Security"
  }
}

# RDS Database
module "rds" {
  source = "../../../../modules/rds"

  identifier     = "${var.project_name}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Networking
  subnet_ids         = data.terraform_remote_state.networking.outputs.private_subnet_ids
  security_group_ids = [module.db_security_group.id]

  # Backups
  backup_retention_days = var.db_backup_retention_period
  backup_window         = "03:00-04:00"
  maintenance_window    = "Mon:04:00-Mon:05:00"

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 60

  # Protection
  deletion_protection = var.environment == "prod"
  skip_final_snapshot = var.environment != "prod"

  tags = {
    Purpose = "Application Database"
  }
}
