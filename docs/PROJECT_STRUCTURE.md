# Project Structure

## Directory Layout

```
Terraform-standardisation/
├── .pre-commit-config.yaml    # Pre-commit hooks configuration
├── .tflint.hcl                # TFLint configuration
├── .tfsec.json                # TFSec security scanner config
├── .gitlab-ci.yml             # CI/CD pipeline configuration
├── .gitignore                 # Git ignore patterns
├── README.md                  # Main documentation
│
├── backend-config/            # Backend configuration per environment
│   ├── dev.hcl
│   ├── staging.hcl
│   └── prod.hcl
│
├── docs/                      # Documentation
│   ├── QUICK_START.md
│   ├── security.MD
│   ├── SETUP_CHECKLIST.md
│   ├── TROUBLESHOOTING.md
│   └── PROJECT_STRUCTURE.md
│
├── modules/                   # Reusable Terraform modules
│   ├── versions.tf            # Global version constraints
│   ├── README.md
│   │
│   ├── vpc/                   # VPC module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   │
│   ├── ec2/                   # EC2 instance module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   │
│   ├── rds/                   # RDS database module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   │
│   ├── security-groups/       # Security group module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   │
│   └── iam/                   # IAM role module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
│
└── projects/                  # Individual project deployments
    └── project-charan/        # Your project
        ├── dev/               # Development environment
        │   ├── main.tf        # Main configuration
        │   ├── backend.tf     # Backend configuration
        │   ├── variables.tf   # Variable definitions
        │   ├── locals.tf      # Local values
        │   ├── outputs.tf     # Output values
        │   ├── user_data.sh   # EC2 user data script
        │   └── terraform.tfvars.example
        │
        ├── staging/           # Staging environment
        │   └── main.tf
        │
        └── prod/              # Production environment
            └── main.tf
```

## Module Design

### Reusable Modules (`modules/`)

Each module is self-contained and reusable:
- **Input**: Variables defined in `variables.tf`
- **Logic**: Resources defined in `main.tf`
- **Output**: Values exposed in `outputs.tf`
- **Versions**: Provider requirements in `versions.tf`

### Project Structure (`projects/`)

Each project has three environments:
- **dev**: Development (cost-optimized, less redundancy)
- **staging**: Pre-production (similar to prod)
- **prod**: Production (HA, backups, deletion protection)

## File Purposes

| File | Purpose |
|------|---------|
| `main.tf` | Primary resource definitions and module calls |
| `variables.tf` | Input variable declarations |
| `outputs.tf` | Output value definitions |
| `locals.tf` | Local value computations |
| `backend.tf` | Remote state backend configuration |
| `versions.tf` | Terraform and provider version constraints |
| `terraform.tfvars` | Variable values (gitignored, secrets) |
| `terraform.tfvars.example` | Example values (committed, no secrets) |

## Module Usage Pattern

```hcl
# In projects/project-charan/dev/main.tf

module "vpc" {
  source = "../../../modules/vpc"  # Relative path to module
  
  # Required inputs
  cidr_block   = var.vpc_cidr
  environment  = var.environment
  project_name = var.project_name
  
  # Optional inputs with defaults
  enable_nat_gateway = var.enable_nat_gateway
  
  # Common tags
  tags = local.common_tags
}

# Use module outputs
resource "aws_instance" "web" {
  subnet_id = module.vpc.public_subnet_ids[0]
  # ...
}
```

## Backend Configuration

State is stored remotely in S3 with DynamoDB locking:
- **Isolation**: Each environment has separate state file
- **Locking**: DynamoDB prevents concurrent modifications
- **Encryption**: State files are encrypted at rest
- **Versioning**: S3 versioning enables state recovery

## Best Practices

1. **Never commit secrets**: Use Terraform Cloud or AWS Secrets Manager
2. **One environment per directory**: Clear separation of concerns
3. **Shared modules**: DRY principle for infrastructure code
4. **Version pinning**: Lock provider versions for stability
5. **Remote state**: Always use remote backend for teams
6. **Tagging**: Apply consistent tags via locals.tf
