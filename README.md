# Terraform Infrastructure Repository

A scalable, secure, and team-friendly Terraform monorepo for managing infrastructure across multiple projects.

## 📋 Quick Start

```bash
# 1. Clone the repo
git clone <repo-url>
cd terraform-infrastructure

# 2. Install dependencies
./scripts/setup-project.sh

# 3. Choose your project
cd projects/project-alice/dev

# 4. Initialize and plan
terraform init -backend-config=../../backend-config/dev.hcl
terraform plan
```

## 📁 Repository Structure

- **modules/**: Reusable infrastructure components (VPC, RDS, EC2, etc.)
- **projects/**: Individual team member projects with dev/staging/prod environments
- **scripts/**: Automation and utility scripts
- **docs/**: Documentation and runbooks
- **.gitlab/**: CI/CD pipeline configurations

## 🔒 Security First

This repository **never contains secrets**:
- AWS keys → AWS IAM Roles (CI/CD) or Terraform Cloud
- Database passwords → Terraform Cloud sensitive variables
- State files → Remote backend (S3) with encryption
- API keys → AWS Secrets Manager

See [docs/SECURITY.md](docs/SECURITY.md) for detailed security practices.

## 📖 Documentation

- [QUICK_START.md](docs/QUICK_START.md) - Get running in 10 minutes
- [SECURITY.md](docs/SECURITY.md) - Security practices and compliance
- [PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md) - Understanding the layout
- [RUNBOOKS.md](docs/RUNBOOKS.md) - Common deployment tasks
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Debugging issues

## 🚀 Getting Started with a New Project

```bash
./scripts/setup-project.sh my-new-project
```

This creates a complete project structure with all necessary files.

## 📋 Pre-requisites

- Terraform 1.7.0 or higher
- AWS CLI v2
- Git with pre-commit hooks installed
- Python 3.8+ (for pre-commit)

## 🔄 CI/CD Pipeline

All commits trigger:
1. **Validate** - Terraform format and syntax checking
2. **Scan** - Security scanning with tfsec
3. **Plan** - Generate terraform plan
4. Merge to main → **Apply** (manual approval required)

See [.gitlab/workflows/](gitlab/workflows/) for pipeline definitions.

## 💡 Common Commands

```bash
# Validate your changes
terraform fmt -check
terraform validate
tfsec .

# Plan your infrastructure
terraform plan -out=tfplan

# Apply changes (with approval)
terraform apply tfplan

# Check what would be destroyed
terraform plan -destroy

# See current state
terraform state list
terraform state show module.vpc
```

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Run validation and scan
4. Create MR for review
5. After approval, merge to main
6. Pipeline auto-applies

## 📞 Support

For issues, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) or contact the infrastructure team.

