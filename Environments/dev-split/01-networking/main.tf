# Networking Layer - VPC, Subnets, Route Tables
# This is the foundation layer that changes rarely

terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket  = "terraform-state-charan-492267476800"
    key     = "project-charan/dev/networking/terraform.tfstate"
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
      Layer       = "Networking"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../../../modules/vpc"

  cidr_block           = var.vpc_cidr
  project_name         = var.project_name
  environment          = var.environment

  # Subnets
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  # NAT Gateway
  enable_nat_gateway = true

  tags = {
    Description = "VPC for ${var.project_name} ${var.environment}"
  }
}
