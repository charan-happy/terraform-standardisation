terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Bootstrap uses LOCAL state - this will create the remote backend
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "terraform-bootstrap"
      ManagedBy   = "Terraform"
      Environment = "bootstrap"
      Purpose     = "Backend infrastructure"
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "terraform-state-${var.project_prefix}-${local.account_id}"
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to true after initial creation
  }

  tags = {
    Name        = "Terraform State Bucket"
    Description = "Stores Terraform state files"
  }
}

# Enable versioning on the S3 bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable object lock for state locking (replaces DynamoDB)
# Note: Object Lock can only be enabled on bucket creation
# To use S3 native locking, recreate bucket with object_lock_enabled = true

# Enable bucket logging (optional but recommended)
resource "aws_s3_bucket" "log_bucket" {
  count  = var.enable_logging ? 1 : 0
  bucket = "${local.bucket_name}-logs"

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "Terraform State Logs"
  }
}

resource "aws_s3_bucket_logging" "terraform_state" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.log_bucket[0].id
  target_prefix = "state-access-logs/"
}

# DynamoDB table for state locking (optional but recommended)
resource "aws_dynamodb_table" "terraform_locks" {
  count = var.enable_state_locking ? 1 : 0

  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_dynamodb_pitr
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Description = "DynamoDB table for Terraform state locking"
  }
}

# Generate TLS private key for EC2 key pairs
resource "tls_private_key" "ec2_keys" {
  for_each = toset(var.key_pair_names)

  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create EC2 key pairs
resource "aws_key_pair" "ec2_keys" {
  for_each = toset(var.key_pair_names)

  key_name   = each.value
  public_key = tls_private_key.ec2_keys[each.value].public_key_openssh

  tags = {
    Name = each.value
  }
}

# Save private keys locally (secure these files!)
resource "local_sensitive_file" "private_keys" {
  for_each = toset(var.key_pair_names)

  content         = tls_private_key.ec2_keys[each.value].private_key_pem
  filename        = "${path.module}/keys/${each.value}.pem"
  file_permission = "0400"
}

# Create backend configuration files
resource "local_file" "backend_configs" {
  for_each = toset(var.environments)

  filename = "${path.module}/../backend-config/${each.value}.hcl"
  content = templatefile("${path.module}/templates/backend.hcl.tpl", {
    bucket         = aws_s3_bucket.terraform_state.bucket
    key            = "env/${each.value}/terraform.tfstate"
    region         = data.aws_region.current.name
    dynamodb_table = var.enable_state_locking ? aws_dynamodb_table.terraform_locks[0].name : ""
    enable_locking = var.enable_state_locking
  })
}

# Create project-specific backend.tf
resource "local_file" "project_backend" {
  for_each = toset(var.environments)

  filename = "${path.module}/../projects/project-charan/${each.value}/backend.tf"
  content = templatefile("${path.module}/templates/project-backend.tf.tpl", {
    bucket         = aws_s3_bucket.terraform_state.bucket
    key            = "project-charan/${each.value}/terraform.tfstate"
    region         = data.aws_region.current.name
    dynamodb_table = var.enable_state_locking ? aws_dynamodb_table.terraform_locks[0].name : ""
    enable_locking = var.enable_state_locking
  })
}
