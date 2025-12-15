# Compute Layer - EC2, ALB, Security Groups
# Changes frequently - add new instances here

terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket  = "terraform-state-charan-492267476800"
    key     = "project-charan/dev/compute/terraform.tfstate"
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
      Layer       = "Compute"
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

# Read database outputs
data "terraform_remote_state" "database" {
  backend = "s3"

  config = {
    bucket = "terraform-state-charan-492267476800"
    key    = "project-charan/dev/database/terraform.tfstate"
    region = "us-east-1"
  }
}

# Web Server Security Group
module "web_security_group" {
  source = "../../../../modules/security-groups"

  name        = "${var.project_name}-web-sg"
  description = "Security group for web servers"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "SSH from anywhere"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP from anywhere"
    }
  ]
}

# IAM Role for EC2
module "ec2_iam_role" {
  source = "../../../../modules/iam"

  role_name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  create_instance_profile = true
}

# Web Server
module "web_server" {
  source = "../../../../modules/ec2"

  instance_count       = 1
  instance_type        = var.instance_type
  instance_name        = "${var.project_name}-web"
  subnet_ids           = data.terraform_remote_state.networking.outputs.public_subnet_ids
  security_group_id    = module.web_security_group.id
  key_name             = var.ec2_key_name
  iam_instance_profile_name = module.ec2_iam_role.instance_profile_name

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    db_endpoint = data.terraform_remote_state.database.outputs.endpoint
    db_name     = data.terraform_remote_state.database.outputs.db_name
  }))

  root_volume_size = 8
  root_volume_type = "gp3"

  tags = {
    Purpose = "Web Server"
  }
}
