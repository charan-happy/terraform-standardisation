# Setup Checklist

Use this checklist to get your Terraform environment up and running.

## Prerequisites

- [ ] Terraform >= 1.7.0 installed
- [ ] AWS CLI v2 installed and configured
- [ ] Pre-commit installed
- [ ] tflint installed
- [ ] tfsec installed
- [ ] terraform-docs installed
- [ ] Git configured with your identity

## AWS Setup

- [ ] AWS credentials configured (`aws configure`)
- [ ] S3 bucket created for state storage
- [ ] Bucket versioning enabled
- [ ] Bucket encryption enabled
- [ ] DynamoDB table created for locking
- [ ] EC2 key pair created

## Repository Setup

- [ ] Repository cloned
- [ ] Pre-commit hooks installed (`pre-commit install`)
- [ ] tflint initialized (`tflint --init`)
- [ ] Backend config files updated with real bucket names
- [ ] terraform.tfvars created from example (NOT committed)

## First Deployment

- [ ] Navigate to project directory (`cd projects/project-charan/dev`)
- [ ] Run `terraform init`
- [ ] Run `terraform fmt -recursive`
- [ ] Run `terraform validate`
- [ ] Run `terraform plan`
- [ ] Review plan carefully
- [ ] Run `terraform apply` (when ready)

## Security Checks

- [ ] No secrets in .tf files
- [ ] No .tfvars files committed
- [ ] No .tfstate files committed
- [ ] Pre-commit hooks running on every commit
- [ ] tfsec passing with no critical issues

## Troubleshooting

If you encounter issues:
1. Check Terraform version: `terraform version`
2. Check AWS credentials: `aws sts get-caller-identity`
3. Verify backend bucket exists: `aws s3 ls s3://your-bucket-name`
4. Check module paths are correct
5. Run `terraform init -upgrade` to update providers
