
# FILE: docs/SECURITY.md
"""
# Security Best Practices

## Golden Rule: Never Commit Secrets

❌ **NEVER** commit these to git:
- AWS Access Keys / Secret Keys
- Database passwords
- API keys
- Private certificates
- OAuth tokens
- `.tfstate` files
- `.tfvars` files with values

## Secret Storage Solutions

### 1. Terraform Cloud (Recommended)

Free for small teams. Provides:
- Encrypted variable storage
- Audit logging
- Team collaboration
- UI for secret management

**Setup**:
\`\`\`bash
terraform login
# Paste token when prompted
\`\`\`

**Usage**:
\`\`\`hcl
terraform {
  cloud {
    organization = "your-org"
  }
}

variable "db_password" {
  type      = string
  sensitive = true
}
\`\`\`

Then set variable in Terraform Cloud UI.

### 2. AWS Secrets Manager

For runtime secrets (database passwords, API keys):

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/rds/password"
}

resource "aws_db_instance" "main" {
  password = jsondecode(
    data.aws_secretsmanager_secret_version.db_password.secret_string
  )["password"]
}
```

