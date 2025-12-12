
# Quick Start Guide

Get up and running with Terraform infrastructure in 10 minutes.

## Prerequisites

- Terraform 1.7.0 or higher
- AWS CLI v2 configured with credentials
- Git
- Python 3.8+ (for pre-commit)

## Step 1: Clone and Setup

\`\`\`bash
git clone <repo-url>
cd terraform-infrastructure

# Install pre-commit hooks (prevents secrets in commits)
pip install pre-commit
pre-commit install

# Install detect-secrets baseline
detect-secrets scan > .secrets.baseline
\`\`\`

## Step 2: Create S3 Backend (One-time)

\`\`\`bash
./scripts/setup-backend.sh
\`\`\`

## Step 3: Choose Your Project

\`\`\`bash
# List available projects
ls projects/

# Navigate to your project
cd projects/project-alice/dev
\`\`\`

## Step 4: Initialize Terraform

\`\`\`bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (NEVER commit this)
vi terraform.tfvars

# Initialize Terraform
terraform init -backend-config=../../backend-config/dev.hcl
\`\`\`

## Step 5: Plan Your Infrastructure

\`\`\`bash
terraform plan -out=tfplan
\`\`\`

## Step 6: Apply Changes

\`\`\`bash
terraform apply tfplan
\`\`\`

## Storing Secrets Safely

Never commit sensitive variables:

1. **In Terraform Cloud** (Recommended):
   - Create account at app.terraform.io
   - Create organization and workspace
   - Set variables in UI (mark as "Sensitive")

2. **In AWS Secrets Manager**:
   - Store passwords/keys in Secrets Manager
   - Reference in Terraform: \`data.aws_secretsmanager_secret_version\`

3. **In GitLab CI/CD**:
   - Project → Settings → CI/CD → Variables
   - Mark as "Protected"
   - Use in pipeline: \`\${VAR_NAME}\`

## Common Commands

\`\`\`bash
# Validate without AWS calls
terraform validate

# Check formatting
terraform fmt -check -recursive .

# Security scan
tfsec .

# Show what will change
terraform plan -out=tfplan

# Apply approved plan
terraform apply tfplan

# Show current state
terraform state list
terraform state show module.vpc

# Destroy infrastructure
terraform destroy
\`\`\`

