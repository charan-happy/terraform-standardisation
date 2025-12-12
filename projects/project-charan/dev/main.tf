
# Choose ONE backend option - either Terraform Cloud OR S3
# If using Terraform Cloud, comment out backend.tf
# If using S3, comment out the cloud block below

# terraform {
#   cloud {
#     organization = "your-organization-name"
#     
#     workspaces {
#       name = "project-charan-dev"
#     }
#   }
# }

terraform {
  required_version = ">= 1.7.0"

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
    tags = local.common_tags
  }
}

# VPC with public and private subnets
module "vpc" {
  source = "../../../modules/vpc"

  cidr_block         = var.vpc_cidr
  environment        = var.environment
  project_name       = var.project_name
  enable_nat_gateway = var.enable_nat_gateway

  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.common_tags
}

# Security group for web servers
module "web_security_group" {
  source = "../../../modules/security-groups"

  name        = "${var.project_name}-web-sg"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow HTTPS from internet"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_ipv4   = var.admin_cidr
      description = "Allow SSH from admin network"
    }
  ]

  tags = local.common_tags
}

# Security group for RDS database
module "db_security_group" {
  source = "../../../modules/security-groups"

  name        = "${var.project_name}-db-sg"
  description = "Security group for RDS database"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port         = 5432
      to_port           = 5432
      protocol          = "tcp"
      security_group_id = module.web_security_group.id
      description       = "Allow PostgreSQL from web servers"
    }
  ]

  tags = local.common_tags
}

# RDS PostgreSQL database
module "rds" {
  source = "../../../modules/rds"

  identifier        = "${var.project_name}-db"
  engine            = "postgres"
  engine_version     = "15"  # Changed from 15.3 to 15 (major version only)
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password # Sourced from Terraform Cloud

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.db_security_group.id]

  multi_az                        = var.db_multi_az
  backup_retention_days           = var.db_backup_retention_days
  deletion_protection             = var.db_deletion_protection
  skip_final_snapshot             = var.db_skip_final_snapshot
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.common_tags
}

# IAM role for EC2 instances
module "ec2_iam_role" {
  source = "../../../modules/iam"

  role_name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  inline_policies = {
    ssm_access = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ssm:UpdateInstanceInformation",
            "ssmmessages:AcknowledgeMessage",
            "ssmmessages:GetEndpoint",
            "ssmmessages:GetMessages",
            "ec2messages:AcknowledgeMessage",
            "ec2messages:GetEndpoint",
            "ec2messages:GetMessages"
          ]
          Resource = "*"
        }
      ]
    })
    cloudwatch_logs = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = "arn:aws:logs:${var.aws_region}:*:*"
        }
      ]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  create_instance_profile = true

  tags = local.common_tags
}

# EC2 web servers
module "web_servers" {
  source = "../../../modules/ec2"

  instance_count            = var.web_server_count
  instance_type             = var.web_instance_type
  instance_name             = "${var.project_name}-web"
  subnet_ids                = module.vpc.public_subnet_ids
  security_group_id         = module.web_security_group.id
  key_name                  = var.ec2_key_name
  iam_instance_profile_name = module.ec2_iam_role.instance_profile_name

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    db_endpoint = module.rds.endpoint
    db_name     = var.db_name
  }))

  tags = local.common_tags
}
