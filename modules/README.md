# Terraform Modules

Reusable infrastructure components used across all projects.

## Available Modules

### vpc
Creates a VPC with public and private subnets across multiple AZs.

**Inputs:**
- `cidr_block` - CIDR block for the VPC (e.g., "10.0.0.0/16")
- `environment` - Environment name (dev, staging, prod)
- `project_name` - Name of the project
- `enable_nat_gateway` - Create NAT gateway for private subnets

**Outputs:**
- `vpc_id` - VPC ID
- `public_subnet_ids` - List of public subnet IDs
- `private_subnet_ids` - List of private subnet IDs

Example usage:
```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  cidr_block           = "10.0.0.0/16"
  environment          = "dev"
  project_name         = "my-project"
  enable_nat_gateway   = true
  
  tags = local.common_tags
}
```

### rds
Creates a managed RDS database with automatic backups and encryption.

**Inputs:**
- `identifier` - Database identifier
- `engine` - Database engine (postgres, mysql, mariadb)
- `instance_class` - RDS instance type (db.t3.micro, db.t3.small, etc.)
- `allocated_storage` - Storage in GB
- `db_name` - Initial database name
- `username` - Master username
- `password` - Master password (from Terraform Cloud)
- `subnet_ids` - Subnet IDs for DB subnet group

**Outputs:**
- `endpoint` - Database endpoint
- `port` - Database port
- `resource_id` - RDS resource ID for event subscriptions

Example usage:
```hcl
module "rds" {
  source = "../../modules/rds"
  
  identifier         = "myapp-db"
  engine             = "postgres"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  db_name            = "appdb"
  username           = "postgres"
  password           = var.db_password  # From Terraform Cloud
  subnet_ids         = module.vpc.private_subnet_ids
  
  tags = local.common_tags
}
```

### ec2
Creates EC2 instances with proper security group assignment and tagging.

**Inputs:**
- `instance_type` - EC2 instance type (t3.micro, t3.small, etc.)
- `ami` - AMI ID
- `count` - Number of instances
- `subnet_ids` - Subnet IDs for instances
- `security_group_id` - Security group ID
- `instance_name` - Name prefix for instances
- `key_name` - EC2 key pair name

**Outputs:**
- `instance_ids` - List of instance IDs
- `private_ips` - List of private IP addresses

### security_groups
Creates security groups with ingress/egress rules.

**Inputs:**
- `vpc_id` - VPC ID
- `name` - Security group name
- `ingress_rules` - List of ingress rules
- `egress_rules` - List of egress rules

### iam
Creates IAM roles, policies, and instance profiles for EC2 and Lambda.

**Inputs:**
- `role_name` - Name of the IAM role
- `assume_role_policy` - Assume role policy JSON
- `policies` - List of policy ARNs or inline policies

**Outputs:**
- `role_arn` - ARN of the created role
- `instance_profile_name` - Name of the instance profile (for EC2)

## Module Versioning

Modules are versioned inline with the repository. When a module changes:
1. Update the module files
2. Increment version in module's `versions.tf`
3. Update all projects using that module
4. Test in dev environment first

For production-grade setup, consider moving modules to a separate registry.

## Testing Modules

Each module directory contains example usage:

```bash
# Validate module
cd modules/vpc
terraform init
terraform validate
tfsec .
```