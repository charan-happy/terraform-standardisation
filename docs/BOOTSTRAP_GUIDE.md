# 🚀 Complete Bootstrap Guide - Automated Backend Setup

## What Is This?

The `bootstrap/` directory contains Terraform code that **automatically creates all backend infrastructure** needed for your Terraform projects:

- ✅ S3 bucket for state storage (encrypted, versioned)
- ✅ DynamoDB table for state locking
- ✅ EC2 key pairs for SSH access
- ✅ Auto-generated backend configuration files

## Why Use Terraform for Bootstrap?

Instead of manual AWS CLI commands or shell scripts, this uses **Terraform itself** to create the backend. Benefits:

- 🎯 **Declarative** - Clear definition of what gets created
- 🔄 **Repeatable** - Easy to recreate in different accounts/regions
- 📝 **Documented** - Code serves as documentation
- 🛡️ **Version Controlled** - Track changes over time
- 🔧 **Maintainable** - Easy to modify and update

## 🚀 Quick Start (3 Commands)

```bash
# 1. Navigate to bootstrap directory
cd bootstrap

# 2. Run the bootstrap script
./bootstrap.sh

# 3. Done! Use the backend in your projects
cd ../projects/project-charan/dev
terraform init
```

## 📋 Step-by-Step Guide

### Step 1: Navigate to Bootstrap

```bash
cd /path/to/Terraform-standardisation/bootstrap
```

### Step 2: (Optional) Customize Configuration

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Default values are fine for most cases. Customize if needed:

```hcl
# AWS region
aws_region = "us-east-1"

# Bucket name prefix (auto-generates unique name)
project_prefix = "charan"

# Key pairs to create
key_pair_names = [
  "project-charan-dev-key",
  "project-charan-staging-key",
  "project-charan-prod-key"
]

# Environments
environments = ["dev", "staging", "prod"]
```

### Step 3: Run Bootstrap

```bash
./bootstrap.sh
```

This will:
1. Initialize Terraform
2. Show you what will be created
3. Ask for confirmation
4. Create all resources
5. Generate backend config files
6. Save EC2 private keys

**Output:**
```
✅ Bootstrap Complete!

Backend Resources Created:
- S3 Bucket: terraform-state-charan-123456789012
- DynamoDB Table: terraform-locks
- EC2 Key Pairs: project-charan-dev-key, project-charan-staging-key, project-charan-prod-key

Private Keys Saved To:
- bootstrap/keys/*.pem
```

### Step 4: Secure Your Private Keys

```bash
# Keys are already saved with correct permissions (0400)
ls -la keys/

# Optionally copy to SSH directory
cp keys/*.pem ~/.ssh/

# List your keys
ls -l keys/
```

### Step 5: Use in Your Projects

Backend config files are **automatically generated and updated**. Just initialize:

```bash
cd ../projects/project-charan/dev

# Backend is already configured!
terraform init

# Deploy your infrastructure
terraform plan
terraform apply
```

## 🔍 What Gets Created

### 1. S3 Bucket for State

```
Name: terraform-state-{prefix}-{account-id}
Features:
  ✓ Versioning enabled
  ✓ Encryption (AES256)
  ✓ Public access blocked
  ✓ Bucket key enabled
```

### 2. DynamoDB Table for Locking

```
Name: terraform-locks
Features:
  ✓ On-demand billing
  ✓ Point-in-time recovery
  ✓ Hash key: LockID
```

### 3. EC2 Key Pairs

```
Keys: project-charan-{env}-key
Type: RSA 4096-bit
Saved: bootstrap/keys/*.pem
Permissions: 0400 (read-only)
```

### 4. Generated Configuration Files

**backend-config/dev.hcl:**
```hcl
bucket         = "terraform-state-charan-123456789012"
key            = "env/dev/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"
```

**projects/project-charan/dev/backend.tf:**
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-charan-123456789012"
    key            = "project-charan/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## 📁 Directory Structure After Bootstrap

```
bootstrap/
├── main.tf                    # Main configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Outputs
├── bootstrap.sh               # Quick setup script
├── terraform.tfvars           # Your config (gitignored)
├── terraform.tfstate          # Local state (gitignored)
├── .terraform/                # Terraform working dir
├── templates/                 # Config templates
│   ├── backend.hcl.tpl
│   └── project-backend.tf.tpl
└── keys/                      # Generated private keys (gitignored)
    ├── project-charan-dev-key.pem
    ├── project-charan-staging-key.pem
    └── project-charan-prod-key.pem
```

## 🔐 Security Considerations

### Bootstrap State File

The bootstrap uses **local state** (`terraform.tfstate`):
- ✅ Gitignored automatically
- ⚠️ Back it up securely (encrypted location)
- 💡 Contains bucket names and key IDs (not secrets)

### Private Keys

EC2 private keys in `keys/`:
- ✅ Gitignored automatically
- ✅ Permissions set to 0400
- ⚠️ Store in password manager or AWS Secrets Manager
- ⚠️ Never commit to version control

### State Bucket

Automatically secured with:
- ✅ Server-side encryption
- ✅ Versioning (protect against deletion)
- ✅ Public access blocked
- ✅ Access logs (optional)

## 🔄 Updating Bootstrap Resources

Need to add another key pair or change settings?

```bash
cd bootstrap

# Edit terraform.tfvars
nano terraform.tfvars

# Apply changes
terraform plan
terraform apply
```

Config files are automatically regenerated!

## 🗑️ Destroying Bootstrap (Careful!)

⚠️ **WARNING:** This deletes your state bucket and all state files!

Only do this when completely decommissioning:

```bash
cd bootstrap

# First, ensure all project state is migrated/backed up
# Then empty the S3 bucket
aws s3 rm s3://your-bucket-name --recursive

# Destroy resources
terraform destroy
```

## 📊 Cost Estimation

Monthly costs (approximate):

| Resource | Cost |
|----------|------|
| S3 (state files) | ~$0.02/GB + requests |
| DynamoDB (locks) | ~$0.50/month (typical) |
| EC2 Key Pairs | Free |
| **Total** | **< $2/month** |

## 🔧 Advanced Usage

### Multiple AWS Accounts

Run bootstrap in each account:

```bash
# Account 1 (dev)
export AWS_PROFILE=dev
cd bootstrap
./bootstrap.sh

# Account 2 (prod)
export AWS_PROFILE=prod
cd bootstrap
./bootstrap.sh
```

### Different Regions

```bash
# Edit terraform.tfvars
aws_region = "eu-west-1"

# Run bootstrap
./bootstrap.sh
```

### Custom Bucket Name

```hcl
# terraform.tfvars
state_bucket_name = "mycompany-terraform-state"
```

### Import Existing Resources

If resources already exist:

```bash
# Import S3 bucket
terraform import aws_s3_bucket.terraform_state your-bucket-name

# Import DynamoDB table
terraform import aws_dynamodb_table.terraform_locks terraform-locks

# Import key pair
terraform import 'aws_key_pair.ec2_keys["project-charan-dev-key"]' project-charan-dev-key
```

## 📚 Terraform Commands Reference

```bash
# Initialize
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources
terraform state list

# View outputs
terraform output

# Refresh state
terraform refresh

# Format code
terraform fmt

# Validate configuration
terraform validate
```

## 🐛 Troubleshooting

### Issue: "Bucket name already in use"

S3 bucket names are globally unique.

```hcl
# Solution: Change bucket name in terraform.tfvars
state_bucket_name = "terraform-state-yourcompany-unique-id"
```

### Issue: "Key pair already exists"

```bash
# Option 1: Delete existing key
aws ec2 delete-key-pair --key-name project-charan-dev-key

# Option 2: Import existing key
terraform import 'aws_key_pair.ec2_keys["project-charan-dev-key"]' project-charan-dev-key

# Option 3: Use different key name
# Edit key_pair_names in terraform.tfvars
```

### Issue: "Access Denied"

Ensure AWS credentials have permissions:

```bash
# Check current identity
aws sts get-caller-identity

# Required permissions:
- s3:CreateBucket, s3:PutBucket*
- dynamodb:CreateTable
- ec2:CreateKeyPair, ec2:ImportKeyPair
```

### Issue: "Backend initialization failed" in projects

```bash
# The backend config may not be updated
cd bootstrap
terraform refresh  # Regenerate config files

# Or manually verify backend.tf has correct values
```

## ✅ Verification Checklist

After running bootstrap:

- [ ] S3 bucket created and visible in AWS Console
- [ ] DynamoDB table created
- [ ] EC2 key pairs visible in AWS Console
- [ ] Private key files exist in `bootstrap/keys/`
- [ ] backend-config/*.hcl files updated
- [ ] projects/*/backend.tf files updated
- [ ] `terraform output` shows all resources
- [ ] Private keys secured (chmod 400)

## 🎯 Next Steps

After bootstrap completes:

1. **Secure your keys**: Copy to password manager
2. **Test the backend**: `cd ../projects/project-charan/dev && terraform init`
3. **Deploy infrastructure**: `terraform plan && terraform apply`
4. **Setup monitoring**: CloudWatch alarms for DynamoDB
5. **Enable MFA Delete**: On S3 bucket (production)
6. **Backup bootstrap state**: Store `terraform.tfstate` securely

## 💡 Tips & Best Practices

1. ✅ Run bootstrap **once per AWS account/region**
2. ✅ Keep bootstrap state file backed up
3. ✅ Use descriptive project prefixes
4. ✅ Enable CloudTrail for audit logs
5. ✅ Set up cost alerts in AWS
6. ✅ Use different buckets for different environments (optional)
7. ✅ Enable MFA Delete on production state bucket
8. ✅ Regularly rotate EC2 key pairs

## 🆘 Getting Help

1. Check [bootstrap/README.md](README.md)
2. Review Terraform output for errors
3. Check AWS CloudTrail for API errors
4. Verify IAM permissions
5. See [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)

---

**Ready to get started?** Run `./bootstrap.sh` and you're done in 60 seconds! 🚀
