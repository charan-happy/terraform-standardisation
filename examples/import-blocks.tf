# Examples of import blocks for bringing existing resources under Terraform management
# Terraform 1.5+ required

# Example 1: Import existing EC2 instance
import {
  to = aws_instance.existing_web
  id = "i-0abc123def456789"
}

resource "aws_instance" "existing_web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  subnet_id     = "subnet-0123456789"
  
  # Match existing configuration
  tags = {
    Name = "ExistingWebServer"
  }
}

# Example 2: Import RDS instance
import {
  to = aws_db_instance.legacy_db
  id = "legacy-database-identifier"
}

resource "aws_db_instance" "legacy_db" {
  identifier     = "legacy-database-identifier"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"
  # ... match existing settings
}

# Example 3: Import VPC
import {
  to = aws_vpc.imported_vpc
  id = "vpc-0123456789abcdef"
}

resource "aws_vpc" "imported_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "Imported VPC"
  }
}

# Example 4: Import security group
import {
  to = aws_security_group.existing_sg
  id = "sg-0123456789abcdef"
}

resource "aws_security_group" "existing_sg" {
  name        = "existing-security-group"
  description = "Imported security group"
  vpc_id      = aws_vpc.imported_vpc.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Example 5: Import S3 bucket
import {
  to = aws_s3_bucket.existing_bucket
  id = "my-existing-bucket-name"
}

resource "aws_s3_bucket" "existing_bucket" {
  bucket = "my-existing-bucket-name"
  
  tags = {
    Environment = "Production"
  }
}

# Example 6: Import multiple resources with for_each
import {
  to = aws_instance.imported_servers["web-1"]
  id = "i-0abc123def456789"
}

import {
  to = aws_instance.imported_servers["web-2"]
  id = "i-0abc987fed654321"
}

resource "aws_instance" "imported_servers" {
  for_each = {
    web-1 = "i-0abc123def456789"
    web-2 = "i-0abc987fed654321"
  }
  
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  
  tags = {
    Name = each.key
  }
}

# HOW TO USE:
# 1. Add import block with resource ID
# 2. Add matching resource configuration
# 3. Run: terraform plan
#    - Shows what will be imported
# 4. Run: terraform apply
#    - Imports resource into state
# 5. Verify: terraform show
# 6. Optional: Remove import blocks after import

# FINDING RESOURCE IDs:
# EC2: AWS Console or `aws ec2 describe-instances`
# RDS: AWS Console or `aws rds describe-db-instances`
# VPC: AWS Console or `aws ec2 describe-vpcs`
# S3: Bucket name
# Security Groups: AWS Console or `aws ec2 describe-security-groups`

# TIPS:
# - Start with terraform show <resource> to see current config
# - Use AWS CLI to get resource details
# - Import one resource at a time to avoid errors
# - Verify each import before proceeding
