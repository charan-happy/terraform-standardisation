# 🚀 Complete Setup Guide - Make It Work Flawlessly

## ⚡ Quick Start (5 Minutes)

```bash
cd /Users/gudiyathamnagacharan/Documents/internal-poc/Terraform-standardisation

# 1. Install required tools
brew upgrade terraform  # Upgrade to >= 1.7.0
brew install pre-commit tflint tfsec terraform-docs

# 2. Run automated setup
./setup.sh

# 3. Bootstrap backend (creates S3, DynamoDB, EC2 keys automatically)
cd bootstrap
./bootstrap.sh

# 4. Initialize your first project
cd ../projects/project-charan/dev
# Add db_password to terraform.tfvars
terraform init
terraform plan
terraform apply
```

## 📋 Detailed Step-by-Step Instructions

### Step 1: Fix Critical Issues ⚠️

#### A. Upgrade Terraform (REQUIRED)
Your current version: **1.5.7**  
Required version: **>= 1.7.0**

```bash
brew upgrade terraform
terraform version  # Verify >= 1.7.0
```

#### B. Fix Directory Name (if exists)
If you see `projecdts` directory:
```bash
cd /Users/gudiyathamnagacharan/Documents/internal-poc/Terraform-standardisation
mv projecdts projects  # Only if projecdts exists
```

### Step 2: Install Required Tools 🔧

```bash
# Check what's installed
terraform version    # ✓ Installed (needs upgrade)
aws --version        # ✓ Installed
pre-commit --version # ✗ Missing
tflint --version     # ✗ Missing
tfsec --version      # ✗ Missing

# Install missing tools
brew install pre-commit tflint tfsec terraform-docs

# Or install all at once
brew install terraform pre-commit tflint tfsec terraform-docs awscli
```

### Step 3: Setup Development Environment 🛠️

```bash
cd /Users/gudiyathamnagacharan/Documents/internal-poc/Terraform-standardisation

# Install pre-commit hooks
pre-commit install

# Initialize tflint
tflint --init

# Test hooks (optional)
pre-commit run --all-files
```

### Step 4: Bootstrap Backend Infrastructure ☁️

#### Option A: Terraform Bootstrap (Recommended - Fully Automated)
```bash
cd bootstrap

# Copy and optionally customize config
cp terraform.tfvars.example terraform.tfvars

# Run bootstrap (creates everything automatically)
./bootstrap.sh

# That's it! S3, DynamoDB, and EC2 keys are created
```

This Terraform bootstrap will:
- ✅ Create S3 bucket for state (with versioning, encryption)
- ✅ Create DynamoDB table for state locking
- ✅ Generate EC2 key pairs (dev, staging, prod)
- ✅ Auto-update all backend configuration files
- ✅ Save private keys securely to `bootstrap/keys/`

#### Option B: Shell Script
```bash
./setup-backend.sh
# Follow the prompts
```

#### Option C: Manual Setup
```bash
# Set AWS credentials
export AWS_PROFILE=your-profile  # or run: aws configure

# Create S3 bucket (choose unique name)
BUCKET_NAME="terraform-state-yourcompany-$(aws sts get-caller-identity --query Account --output text)"

aws s3 mb "s3://$BUCKET_NAME" --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Create EC2 key pair
aws ec2 create-key-pair \
  --key-name project-charan-dev-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/project-charan-dev-key.pem

chmod 400 ~/.ssh/project-charan-dev-key.pem
```

#### Update Configuration Files
Edit these files and replace `your-terraform-state-bucket` with your actual bucket name:
- `backend-config/dev.hcl`
- `backend-config/staging.hcl`
- `backend-config/prod.hcl`
- `projects/project-charan/dev/backend.tf`

### Step 5: Configure Your Project 📝

```bash
cd projects/project-charan/dev

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (DO NOT COMMIT THIS FILE!)
nano terraform.tfvars
```

Required values in `terraform.tfvars`:
```hcl
aws_region          = "us-east-1"
environment         = "dev"
project_name        = "project-charan"
vpc_cidr            = "10.0.0.0/16"
enable_nat_gateway  = false

# Database (SENSITIVE - never commit)
db_password = "YourSecurePassword123!"
db_username = "postgres"

# EC2
ec2_key_name = "project-charan-dev-key"
web_server_count = 1
```

### Step 6: Initialize Terraform 🎯

```bash
cd projects/project-charan/dev

# Initialize (downloads providers and modules)
terraform init

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Preview changes (dry-run)
terraform plan

# Apply when ready
terraform apply
```

### Step 7: Verify Everything Works ✅

```bash
# Run security scan
tfsec .

# Run linter
tflint

# Run pre-commit checks
pre-commit run --all-files

# Check state
terraform state list
```

## 🎨 Optional Enhancements

### Setup Git Pre-commit Hooks
Already done if you ran `./setup.sh`, but manually:
```bash
pre-commit install
pre-commit run --all-files
```

### Configure VS Code (Optional)
Install extensions:
- HashiCorp Terraform
- Terraform Autocomplete
- AWS Toolkit

### Enable Debug Logging (if troubleshooting)
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log
terraform plan
```

## 📚 Important Files Reference

| File | Purpose | Location |
|------|---------|----------|
| `setup.sh` | Automated setup script | Root |
| `setup-backend.sh` | AWS backend setup | Root |
| `terraform.tfvars` | Your secrets (gitignored) | dev/staging/prod |
| `backend.tf` | Backend configuration | dev/staging/prod |
| `.pre-commit-config.yaml` | Git hooks config | Root |
| `.tflint.hcl` | Linter config | Root |

## 🔒 Security Checklist

- [ ] Never commit `terraform.tfvars`
- [ ] Never commit `.tfstate` files
- [ ] Never commit AWS credentials
- [ ] Enable S3 bucket encryption
- [ ] Enable S3 bucket versioning
- [ ] Block public access on S3 bucket
- [ ] Use strong passwords for RDS
- [ ] Restrict SSH access (`admin_cidr`)
- [ ] Enable deletion protection in prod
- [ ] Use AWS Secrets Manager for sensitive data

## 🚨 Common Issues & Solutions

### Issue: "Backend initialization required"
```bash
cd projects/project-charan/dev
terraform init -reconfigure
```

### Issue: "Module not found"
Check relative paths in main.tf:
```hcl
source = "../../../modules/vpc"  # Correct for projects/project-charan/dev
```

### Issue: "InvalidKeyPair.NotFound"
```bash
# Create the key pair
aws ec2 create-key-pair --key-name project-charan-dev-key \
  --query 'KeyMaterial' --output text > ~/.ssh/project-charan-dev-key.pem
chmod 400 ~/.ssh/project-charan-dev-key.pem
```

### Issue: "Access Denied"
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify you have required permissions
aws iam get-user
```

## 📖 Documentation

- [Setup Checklist](docs/SETUP_CHECKLIST.md) - Detailed checklist
- [Quick Start](docs/QUICK_START.md) - Get started in 10 minutes
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues
- [Project Structure](docs/PROJECT_STRUCTURE.md) - Understanding the layout
- [Security](docs/security.MD) - Security best practices

## 🎯 Success Criteria

You're ready when:
- ✅ All tools installed and working
- ✅ Pre-commit hooks installed
- ✅ AWS backend created and configured
- ✅ `terraform init` succeeds
- ✅ `terraform validate` passes
- ✅ `terraform plan` shows expected resources
- ✅ No secrets committed to Git
- ✅ All pre-commit hooks pass

## 🆘 Need Help?

1. Check logs: `TF_LOG=DEBUG terraform plan 2>&1 | tee debug.log`
2. Review [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
3. Verify AWS: `aws sts get-caller-identity`
4. Check versions: `terraform version`, `aws --version`
5. Test AWS access: `aws s3 ls`, `aws ec2 describe-regions`

## 🎉 What's Next?

After everything works:
1. **Test deployment**: `terraform apply` in dev
2. **Setup staging**: Copy dev config to staging/
3. **Setup prod**: Copy and adjust for production
4. **CI/CD**: Configure GitLab CI/CD pipeline
5. **Monitoring**: Setup CloudWatch dashboards
6. **Backups**: Verify RDS backups working
7. **Documentation**: Document your specific configurations

---

**Current Status**: Run `./setup.sh` to check your progress!

---

## 🎯 New: Automated Bootstrap

The `bootstrap/` directory contains Terraform code that automatically creates all backend infrastructure:

```bash
cd bootstrap
./bootstrap.sh
```

This is the **recommended approach** - it uses Terraform itself to create the backend resources!

See [bootstrap/README.md](bootstrap/README.md) for details.
