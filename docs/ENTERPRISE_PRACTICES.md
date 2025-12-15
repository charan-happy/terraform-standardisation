# Enterprise Terraform Best Practices Guide

## 1. Managing Multiple EC2 Instances

### Same Configuration (Scaling)
Use `count` when you need multiple identical instances:

```hcl
module "web_servers" {
  source = "../../../modules/ec2"
  
  instance_count = 3  # Creates 3 identical instances
  instance_type  = "t3.micro"
  # ... other config
}
```

**When to use:** Auto-scaling groups, web server clusters, identical workers

### Slightly Different Configuration
Use `for_each` when instances differ slightly:

```hcl
module "app_servers" {
  source = "../../../modules/ec2"
  
  for_each = {
    api    = { type = "t3.small", team = "Backend" }
    worker = { type = "t3.micro", team = "Backend" }
  }
  
  instance_type = each.value.type
  tags = { Team = each.value.team }
}
```

**When to use:** Different roles (API, Worker, Cache), different teams, different configs

### Completely Different Configuration
Create separate module calls:

```hcl
module "web_server" {
  source = "../../../modules/ec2"
  # Web server config
}

module "monitoring_server" {
  source = "../../../modules/ec2"
  # Monitoring config (different SG, IAM, size, etc.)
}
```

**When to use:** Different purposes (web, monitoring, database), different security requirements

---

## 2. Change Tracking & Auditing (Enterprise Level)

### A. Git-Based Tracking (GitOps)

**Setup:**
```bash
# .gitlab-ci.yml or .github/workflows/terraform.yml
terraform plan -out=tfplan
terraform show -json tfplan > plan.json

# Tag each deployment
git tag -a "deploy-$(date +%Y%m%d-%H%M%S)" -m "Deployed by $CI_COMMIT_AUTHOR"
```

**Track who made changes:**
- Every change goes through Pull Request/Merge Request
- Require code reviews (minimum 2 approvers)
- Use branch protection rules
- Enable commit signing

### B. Terraform State Audit

**Add to backend configuration:**
```hcl
terraform {
  backend "s3" {
    bucket  = "terraform-state-bucket"
    key     = "project/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    
    # S3 versioning captures every state change
    # Enable versioning on the bucket!
  }
}
```

**Query state history:**
```bash
# List all versions
aws s3api list-object-versions \
  --bucket terraform-state-bucket \
  --prefix project/terraform.tfstate

# Download specific version
aws s3api get-object \
  --bucket terraform-state-bucket \
  --key project/terraform.tfstate \
  --version-id VERSION_ID \
  state-backup.tfstate
```

### C. Comprehensive Tagging Strategy

```hcl
locals {
  common_tags = {
    # Ownership
    Owner        = "charan@company.com"
    Team         = "Platform Engineering"
    CostCenter   = "Engineering-001"
    
    # Environment & Project
    Environment  = var.environment
    Project      = var.project_name
    
    # Change Tracking
    ManagedBy       = "Terraform"
    Repository      = "internal-poc/Terraform-standardisation"
    GitCommitSHA    = var.git_commit_sha    # From CI/CD
    GitBranch       = var.git_branch
    GitAuthor       = var.git_author
    DeployedBy      = var.deployed_by
    DeploymentTime  = timestamp()
    
    # Compliance
    ComplianceLevel = "Internal"
    BackupPolicy    = "Daily"
    DataClassification = "Confidential"
  }
}
```

**Set in CI/CD:**
```yaml
# GitLab CI
terraform apply \
  -var="git_commit_sha=$CI_COMMIT_SHA" \
  -var="git_branch=$CI_COMMIT_BRANCH" \
  -var="git_author=$CI_COMMIT_AUTHOR" \
  -var="deployed_by=$GITLAB_USER_LOGIN"
```

### D. AWS CloudTrail Integration

```hcl
resource "aws_cloudtrail" "audit" {
  name           = "infrastructure-audit"
  s3_bucket_name = aws_s3_bucket.audit_logs.id
  
  enable_log_file_validation   = true
  is_multi_region_trail        = true
  include_global_service_events = true
}
```

**Query CloudTrail:**
```bash
# Who created this EC2 instance?
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=i-047a46960a42b79b7 \
  --max-results 50

# All changes by a user
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=charan \
  --start-time 2025-12-01 \
  --end-time 2025-12-12
```

### E. Change Notifications

```hcl
# SNS topic for alerts
resource "aws_sns_topic" "infra_changes" {
  name = "infrastructure-changes"
}

# EventBridge rule
resource "aws_cloudwatch_event_rule" "ec2_changes" {
  name = "ec2-state-changes"
  
  event_pattern = jsonencode({
    source = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}
```

### F. Terraform Enterprise/Cloud Features

If using Terraform Cloud/Enterprise:
- **Sentinel Policies**: Enforce standards before apply
- **Cost Estimation**: Preview costs before deployment
- **Run History**: Complete audit trail with diffs
- **RBAC**: Control who can approve/apply changes
- **Audit Logs**: Built-in audit logging

---

## 3. Avoiding Disruption to Existing Infrastructure

### A. Use Targeted Apply

```bash
# Only modify specific resources
terraform apply -target=module.new_server

# Add new resource without touching existing
terraform apply -target=module.alb
```

### B. Use Terraform Workspaces for Isolation

```bash
# Create isolated workspace for testing
terraform workspace new feature-test
terraform apply  # Changes only affect this workspace

# Switch back to production
terraform workspace select prod
```

### C. State Isolation Strategy

**Separate state files per component:**
```
projects/
  project-charan/
    networking/      # VPC, subnets (rarely changes)
      backend.tf
      main.tf
    compute/         # EC2, ALB (changes often)
      backend.tf
      main.tf
    database/        # RDS (critical, rarely changes)
      backend.tf
      main.tf
```

Each has separate state file:
- `networking/terraform.tfstate`
- `compute/terraform.tfstate`
- `database/terraform.tfstate`

Changes to compute don't risk affecting database!

### D. Use Resource Lifecycle Rules

```hcl
resource "aws_db_instance" "main" {
  # ... config
  
  lifecycle {
    prevent_destroy = true  # Can't be destroyed accidentally
    
    ignore_changes = [
      password  # Ignore password changes in Terraform
    ]
    
    create_before_destroy = true  # Create new before destroying old
  }
}
```

### E. Use Terraform Plan Files

```bash
# Generate plan and review
terraform plan -out=tfplan

# Review the plan file
terraform show tfplan

# Apply ONLY what was planned (no surprises)
terraform apply tfplan
```

### F. Import Existing Resources

```bash
# Add existing resource to Terraform without recreating
terraform import module.existing_server.aws_instance.main i-existing123

# Now Terraform manages it without disruption
```

---

## 4. Adding New Resources (ALB Example)

### Step 1: Create Module

I've created a complete ALB module at:
```
modules/alb/
  ├── main.tf
  ├── variables.tf
  ├── outputs.tf
  └── versions.tf
```

### Step 2: Use Module in Project

```hcl
# In projects/project-charan/dev/main.tf

module "alb" {
  source = "../../../modules/alb"
  
  name       = "${var.project_name}-alb"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  
  # ... configuration
}
```

### Step 3: Targeted Deployment

```bash
# Only create ALB, don't touch existing resources
terraform apply -target=module.alb
```

### Process for Any New Resource:

1. **Create module** in `modules/` directory
2. **Test in dev** environment first
3. **Use targeted apply** to isolate changes
4. **Review plan carefully** before applying
5. **Tag appropriately** for tracking
6. **Document** in README

---

## 5. Enterprise Workflow

```
Developer       → Feature Branch → Pull Request
                                      ↓
Code Review     → 2 Approvers    → terraform plan (automated)
                                      ↓
Approval        → Merge to main  → terraform apply (automated)
                                      ↓
Monitoring      → CloudWatch     → SNS Notifications
                  CloudTrail       Audit Logs
```

### CI/CD Pipeline Example

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - plan
  - apply

validate:
  stage: validate
  script:
    - terraform init
    - terraform validate
    - terraform fmt -check

plan:
  stage: plan
  script:
    - terraform plan -out=tfplan
    - terraform show -json tfplan > plan.json
  artifacts:
    paths:
      - tfplan
      - plan.json

apply:
  stage: apply
  when: manual  # Require manual approval
  only:
    - main
  script:
    - |
      terraform apply tfplan \
        -var="git_commit_sha=$CI_COMMIT_SHA" \
        -var="git_author=$CI_COMMIT_AUTHOR" \
        -var="deployed_by=$GITLAB_USER_LOGIN"
    - git tag "deploy-$(date +%Y%m%d-%H%M%S)"
```

---

## 6. Checklist for Production Changes

- [ ] Code reviewed by 2+ people
- [ ] `terraform plan` shows expected changes only
- [ ] No unintended resource destruction
- [ ] Tags include change tracking info
- [ ] Notifications configured
- [ ] Backup/rollback plan ready
- [ ] Change documented in CHANGELOG
- [ ] Stakeholders notified
- [ ] Deployment window scheduled
- [ ] Monitoring alerts configured

---

## 7. Rollback Strategy

```bash
# Option 1: Revert Git commit
git revert HEAD
terraform apply

# Option 2: Restore previous state
aws s3api get-object \
  --bucket terraform-state-bucket \
  --key project/terraform.tfstate \
  --version-id PREVIOUS_VERSION \
  terraform.tfstate
  
terraform apply -state=terraform.tfstate

# Option 3: Import and fix
terraform import aws_instance.main i-previous-instance
terraform apply
```

---

## Files to Review:

1. `ec2-examples.tf.example` - Multiple EC2 configuration patterns
2. `alb-example.tf.example` - ALB integration example
3. `audit-tracking.tf.example` - Enterprise audit setup
4. `modules/alb/` - Complete ALB module

## Next Steps:

1. Enable S3 versioning on state bucket
2. Set up CloudTrail
3. Configure SNS notifications
4. Implement CI/CD pipeline
5. Train team on GitOps workflow
