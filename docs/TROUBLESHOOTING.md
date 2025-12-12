# Troubleshooting Guide

## Common Issues and Solutions

### Terraform Init Fails

**Error:** `Error loading backend config`
```
Solution:
1. Check backend.tf has correct bucket name
2. Verify bucket exists: aws s3 ls s3://your-bucket-name
3. Check AWS credentials: aws sts get-caller-identity
4. Ensure you have s3:ListBucket permission
```

**Error:** `Failed to get existing workspaces`
```
Solution:
1. Check DynamoDB table exists
2. Verify table name matches in backend config
3. Ensure table has LockID as partition key (String type)
```

### Module Not Found

**Error:** `Module not installed`
```
Solution:
1. Check module source paths in main.tf
2. Run: terraform init -upgrade
3. Verify relative paths are correct from your working directory
```

### Invalid CIDR Block

**Error:** `Error creating VPC: InvalidVpcRange`
```
Solution:
1. Check vpc_cidr variable is valid (e.g., 10.0.0.0/16)
2. Ensure subnet CIDRs are within VPC CIDR range
3. Verify no overlapping subnet CIDRs
```

### Key Pair Not Found

**Error:** `InvalidKeyPair.NotFound`
```
Solution:
1. Create key pair: aws ec2 create-key-pair --key-name your-key
2. Or update ec2_key_name variable to existing key
3. Verify key exists in correct region
```

### RDS Password Requirements

**Error:** `InvalidParameterValue: The parameter MasterUserPassword is not a valid password`
```
Solution:
Password must:
- Be at least 8 characters
- Not contain username
- Contain at least one uppercase, lowercase, number
```

### Permission Denied Errors

**Error:** `AccessDenied` or `UnauthorizedOperation`
```
Solution:
1. Check AWS credentials: aws sts get-caller-identity
2. Verify IAM user/role has required permissions
3. Check for SCPs or permission boundaries
4. Try with AdministratorAccess (temporarily) to isolate issue
```

### Pre-commit Hook Failures

**Error:** `terraform_validate...Failed`
```
Solution:
1. Run: terraform init in the failing directory
2. Check all required variables are defined
3. Verify provider configuration is correct
```

**Error:** `tfsec...Failed`
```
Solution:
1. Review security issues reported
2. Add exceptions in .tfsec.json if justified
3. Fix security issues (recommended)
```

### State Lock Errors

**Error:** `Error acquiring the state lock`
```
Solution:
1. Check if another process is running terraform
2. Wait for other operation to complete
3. If stuck, force unlock: terraform force-unlock <LOCK_ID>
4. Check DynamoDB table for stuck locks
```

### Conflicting Backend

**Error:** `Backend initialization required`
```
Solution:
You can only have ONE backend configured:
- Either Terraform Cloud (cloud block)
- OR S3 backend (backend "s3" block)
- NOT both
```

## Getting Help

1. Check Terraform docs: https://terraform.io/docs
2. AWS provider docs: https://registry.terraform.io/providers/hashicorp/aws
3. Run with debug: TF_LOG=DEBUG terraform plan
4. Check AWS Console for resource state
