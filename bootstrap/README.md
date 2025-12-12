# Terraform Bootstrap

This directory contains Terraform configuration to bootstrap the backend infrastructure needed for your Terraform projects.

## What It Creates

1. **S3 Bucket** - For storing Terraform state files
   - Versioning enabled
   - Server-side encryption (AES256)
   - Public access blocked
   - Optional access logging

2. **DynamoDB Table** - For state locking
   - On-demand billing
   - Point-in-time recovery (optional)

3. **EC2 Key Pairs** - For SSH access to EC2 instances
   - RSA 4096-bit keys
   - Private keys saved locally

4. **Backend Configuration Files** - Auto-generated
   - backend-config/*.hcl files
   - project backend.tf files

## Why Bootstrap?

Terraform backend resources (S3, DynamoDB) need to exist *before* you can use remote state. This creates a "chicken and egg" problem. The bootstrap configuration solves this by:

1. Using **local state** to create the backend resources
2. Auto-generating backend configuration files
3. Creating EC2 key pairs needed for your infrastructure

Once created, your main Terraform projects can use remote state in S3.

## Usage

### Step 1: Configure

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferences
```

### Step 2: Deploy Bootstrap

```bash
# Initialize Terraform (uses local state)
terraform init

# Review what will be created
terraform plan

# Create the backend resources
terraform apply
```

### Step 3: Secure Your Keys

```bash
# Private keys are saved to bootstrap/keys/
chmod 400 keys/*.pem

# Copy to SSH directory (optional)
cp keys/*.pem ~/.ssh/

# IMPORTANT: Never commit these keys!
```

### Step 4: Use in Your Projects

The backend config files are automatically created and updated. Simply navigate to your project and initialize:

```bash
cd ../projects/project-charan/dev
terraform init  # Will use the new backend automatically
terraform plan
terraform apply
```

## Important Files

- `main.tf` - Main bootstrap configuration
- `variables.tf` - Input variables
- `outputs.tf` - Outputs including next steps
- `terraform.tfvars` - Your configuration (gitignored)
- `terraform.tfstate` - Local state file (gitignored)
- `keys/` - Generated private keys (gitignored)

## Security Considerations

### ⚠️ Bootstrap State

The bootstrap configuration uses **local state** stored in `terraform.tfstate`. This file contains:
- S3 bucket name
- DynamoDB table name
- EC2 key pair IDs

**Important:**
- This file is gitignored
- Back it up securely (encrypted backup, S3 with encryption)
- If lost, you can import existing resources

### 🔐 Private Keys

Private keys are generated in `keys/` directory:
- These are gitignored
- Permissions set to 0400 (read-only by owner)
- Store securely (password manager, AWS Secrets Manager)

### 🛡️ S3 Bucket Security

The bootstrap creates a secure S3 bucket with:
- ✅ Versioning enabled (protect against accidental deletion)
- ✅ Encryption at rest (AES256)
- ✅ Public access blocked
- ✅ Bucket key enabled (cost optimization)

## Customization

### Custom Bucket Name

```hcl
# terraform.tfvars
state_bucket_name = "my-company-terraform-state"
```

### Different Key Pairs

```hcl
# terraform.tfvars
key_pair_names = [
  "my-app-dev-key",
  "my-app-prod-key"
]
```

### Enable Logging

```hcl
# terraform.tfvars
enable_logging = true  # Creates additional S3 bucket for logs
```

## Updating Backend Resources

If you need to modify backend resources later:

```bash
cd bootstrap
terraform plan
terraform apply
```

Changes will automatically update the generated config files.

## Destroying Bootstrap (Careful!)

⚠️ **WARNING:** This will delete your state bucket and lock table!

Only do this if:
- You've migrated all state to another backend
- You're completely decommissioning the infrastructure

```bash
cd bootstrap

# First, delete all state files from S3
aws s3 rm s3://your-bucket-name --recursive

# Then destroy
terraform destroy
```

## Troubleshooting

### Issue: "Bucket name already exists"

S3 bucket names are globally unique. Change the bucket name:

```hcl
state_bucket_name = "terraform-state-yourcompany-${random_string}"
```

### Issue: "Key pair already exists"

If key pairs already exist in AWS:

```bash
# Option 1: Import existing key pairs
terraform import 'aws_key_pair.ec2_keys["project-charan-dev-key"]' project-charan-dev-key

# Option 2: Use different key names in terraform.tfvars
```

### Issue: "Access Denied"

Ensure your AWS credentials have permissions:
- s3:CreateBucket, s3:PutBucketVersioning, s3:PutEncryptionConfiguration
- dynamodb:CreateTable
- ec2:CreateKeyPair

## Migration from Existing Backend

If you already have a backend:

1. Keep your existing backend temporarily
2. Run bootstrap to create new resources
3. Migrate state: `terraform init -migrate-state`
4. Verify everything works
5. Decommission old backend

## Outputs

After applying, you'll see:

- S3 bucket name and ARN
- DynamoDB table name and ARN
- Created key pair names
- Private key file locations
- Next steps guide

## Best Practices

1. ✅ Run bootstrap once per AWS account/region
2. ✅ Back up the local terraform.tfstate file
3. ✅ Secure private keys properly
4. ✅ Use different buckets for different environments (if needed)
5. ✅ Enable MFA Delete on state bucket (production)
6. ✅ Set up CloudWatch alarms for DynamoDB
7. ✅ Use IAM policies to restrict state access

## Cost Estimation

Approximate monthly costs:

- S3 bucket: $0.023 per GB stored + requests
- DynamoDB: Pay-per-request (very low, typically < $1/month)
- Total: Usually < $5/month for typical usage

## Support

For issues:
1. Check Terraform output for detailed error messages
2. Review AWS CloudTrail for API errors
3. Verify IAM permissions
4. Check [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
