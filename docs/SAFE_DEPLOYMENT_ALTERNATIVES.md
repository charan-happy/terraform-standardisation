# Safe Deployment Alternatives to -target

Using `terraform apply -target` is **discouraged for regular use** as it can create inconsistent state. Here are better enterprise alternatives:

---

## 1. **Separate State Files (RECOMMENDED)** ⭐

Split your infrastructure into independent Terraform root modules with separate state files.

### Current Structure (Single State):
```
projects/project-charan/dev/
  ├── main.tf           # Everything in one state
  ├── backend.tf        # One state file
  └── terraform.tfstate # All resources
```

### Better Structure (Isolated States):
```
projects/project-charan/dev/
  ├── 01-networking/    # VPC, Subnets (changes rarely)
  │   ├── main.tf
  │   ├── backend.tf    # state: networking/terraform.tfstate
  │   └── outputs.tf
  │
  ├── 02-database/      # RDS (critical, changes rarely)
  │   ├── main.tf
  │   ├── backend.tf    # state: database/terraform.tfstate
  │   ├── data.tf       # Read networking outputs
  │   └── outputs.tf
  │
  ├── 03-compute/       # EC2, ALB (changes frequently)
  │   ├── main.tf
  │   ├── backend.tf    # state: compute/terraform.tfstate
  │   ├── data.tf       # Read networking + database outputs
  │   └── outputs.tf
  │
  └── 04-monitoring/    # CloudWatch, SNS (independent)
      ├── main.tf
      ├── backend.tf    # state: monitoring/terraform.tfstate
      └── outputs.tf
```

### Benefits:
✅ Changes to compute **cannot** affect database
✅ Different teams can own different states
✅ Faster plan/apply (smaller state)
✅ Easier rollback (per-component)
✅ Better security (separate IAM permissions per state)

### How to Share Data Between States:

**Step 1: Export outputs** ([01-networking/outputs.tf](01-networking/outputs.tf))
```hcl
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID for use by other modules"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "Public subnet IDs"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "Private subnet IDs"
}
```

**Step 2: Read outputs in dependent module** ([03-compute/data.tf](03-compute/data.tf))
```hcl
# Read networking outputs from S3 state
data "terraform_remote_state" "networking" {
  backend = "s3"
  
  config = {
    bucket = "terraform-state-charan-492267476800"
    key    = "project-charan/dev/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

# Read database outputs
data "terraform_remote_state" "database" {
  backend = "s3"
  
  config = {
    bucket = "terraform-state-charan-492267476800"
    key    = "project-charan/dev/database/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**Step 3: Use the data** ([03-compute/main.tf](03-compute/main.tf))
```hcl
module "web_server" {
  source = "../../../../modules/ec2"
  
  # Use networking outputs
  subnet_ids = data.terraform_remote_state.networking.outputs.public_subnet_ids
  vpc_id     = data.terraform_remote_state.networking.outputs.vpc_id
  
  # Use database outputs for user_data
  user_data = templatefile("user_data.sh", {
    db_endpoint = data.terraform_remote_state.database.outputs.endpoint
  })
}
```

**Step 4: Deploy independently**
```bash
# Deploy networking first
cd 01-networking
terraform apply  # Safe - only network changes

# Then database
cd ../02-database
terraform apply  # Safe - only database changes

# Finally compute (most frequent changes)
cd ../03-compute
terraform apply  # Safe - only compute changes
```

---

## 2. **Terraform Workspaces**

Create isolated environments for testing changes before production.

```bash
# Create test workspace
terraform workspace new feature-alb-test
terraform apply  # Creates ALB in isolated state

# Verify it works
# Test thoroughly

# Switch to production
terraform workspace select prod
terraform apply  # Now apply to production
```

### When to Use:
- Testing new resources before production
- Feature branches
- Per-developer sandboxes

### Limitations:
- Same backend, different state files
- Not for long-term isolation
- Can be confusing with many workspaces

---

## 3. **Plan Files (Most Common)**

Generate a plan, review it thoroughly, then apply only that plan.

```bash
# Step 1: Generate plan
terraform plan -out=tfplan

# Step 2: Review carefully
terraform show tfplan

# Check specific resources
terraform show -json tfplan | jq '.resource_changes[] | select(.change.actions != ["no-op"])'

# Step 3: Apply ONLY what was planned
terraform apply tfplan  # Cannot add surprise changes

# Step 4: Save plan for audit
terraform show -json tfplan > plan-$(date +%Y%m%d-%H%M%S).json
git add plan-*.json
git commit -m "Applied infrastructure changes"
```

### Benefits:
✅ No surprises - applies exactly what was reviewed
✅ Can be reviewed by multiple people
✅ Audit trail of what was changed
✅ Required for enterprise approval workflows

---

## 4. **Moved Blocks (Terraform 1.1+)** ⭐

Refactor infrastructure without recreating resources.

### Problem:
```hcl
# Old structure
module "server" {
  source = "..."
}

# Want to rename to:
module "web_server" {
  source = "..."
}

# Without moved block: Destroys old, creates new! 😱
```

### Solution:
```hcl
# New name
module "web_server" {
  source = "..."
}

# Tell Terraform this is the same resource
moved {
  from = module.server
  to   = module.web_server
}
```

**Result:** Resource is renamed in state, **NOT recreated**! ✅

### Common Use Cases:

**Renaming resources:**
```hcl
moved {
  from = aws_instance.server
  to   = aws_instance.web_server
}
```

**Moving to modules:**
```hcl
moved {
  from = aws_security_group.web
  to   = module.web_security_group.aws_security_group.main
}
```

**Refactoring count to for_each:**
```hcl
moved {
  from = aws_instance.web[0]
  to   = aws_instance.web["primary"]
}

moved {
  from = aws_instance.web[1]
  to   = aws_instance.web["secondary"]
}
```

---

## 5. **Import Blocks (Terraform 1.5+)** ⭐

Bring existing AWS resources under Terraform management without recreating.

### Old Way (Manual):
```bash
# Manual import
terraform import aws_instance.existing i-0abc123

# Then write matching config - tedious!
```

### New Way (Declarative):
```hcl
# Declare what to import
import {
  to = aws_instance.existing
  id = "i-0abc123"
}

# Write the configuration
resource "aws_instance" "existing" {
  instance_type = "t3.micro"
  ami           = "ami-0c55b159cbfafe1f0"
  # ... match existing resource
}
```

```bash
# Terraform generates the import plan
terraform plan  # Shows what will be imported

# Apply the import
terraform apply  # Imports without recreating
```

### Use Cases:
- Manually created resources
- Resources from other Terraform states
- Migrating from other IaC tools
- Disaster recovery

---

## 6. **Replace Flag (Selective Recreation)**

Force recreate specific resources without affecting others.

```bash
# Recreate just one instance
terraform apply -replace="module.web_server.aws_instance.main[0]"

# Multiple resources
terraform apply \
  -replace="aws_instance.web[0]" \
  -replace="aws_instance.web[1]"
```

### When to Use:
- Instance corrupted/unhealthy
- Need to apply user_data changes
- Testing disaster recovery
- Rotating EC2 instances

### vs -target:
- `-replace`: Recreates specific resources cleanly
- `-target`: Partially applies (can cause drift)

---

## 7. **Terragrunt (Advanced)**

Terragrunt wraps Terraform for better DRY and state management.

```hcl
# terragrunt.hcl
terraform {
  source = "../../../modules//ec2"
}

include "root" {
  path = find_in_parent_folders()
}

dependencies {
  paths = ["../networking", "../database"]
}

inputs = {
  instance_type = "t3.micro"
  # ...
}
```

```bash
# Apply with dependencies in order
terragrunt apply  # Automatically applies networking first

# Apply all
terragrunt run-all apply
```

---

## 8. **Pre-flight Checks**

Validate before applying to catch issues early.

```bash
# Step 1: Format check
terraform fmt -check -recursive

# Step 2: Validation
terraform validate

# Step 3: Security scan
tfsec .

# Step 4: Cost estimation
infracost breakdown --path .

# Step 5: Policy check (if using Sentinel/OPA)
terraform plan -out=tfplan
sentinel apply policy.sentinel tfplan

# Step 6: Plan with detailed output
terraform plan -detailed-exitcode -out=tfplan

# Exit codes:
# 0 = No changes
# 1 = Error
# 2 = Changes present

# Step 7: Review plan
terraform show tfplan | less

# Step 8: Apply
terraform apply tfplan
```

---

## 9. **Lifecycle Meta-Arguments**

Control resource behavior declaratively.

### Prevent Accidental Destruction:
```hcl
resource "aws_db_instance" "main" {
  # ... config
  
  lifecycle {
    prevent_destroy = true  # Cannot destroy via Terraform
  }
}
```

### Create Before Destroy (Zero Downtime):
```hcl
resource "aws_instance" "web" {
  # ... config
  
  lifecycle {
    create_before_destroy = true  # New instance before old deleted
  }
}
```

### Ignore Specific Changes:
```hcl
resource "aws_instance" "web" {
  tags = {
    Name = "web-server"
    # External tools may add tags
  }
  
  lifecycle {
    ignore_changes = [
      tags,                    # Ignore all tag changes
      user_data,              # Ignore user_data drift
      ami,                    # Don't auto-upgrade AMI
    ]
  }
}
```

### Replace Triggered By:
```hcl
resource "aws_instance" "web" {
  # ... config
  
  lifecycle {
    replace_triggered_by = [
      aws_security_group.web.id  # Recreate if SG changes
    ]
  }
}
```

---

## 10. **State Commands (Manual Surgery)**

Direct state manipulation for emergencies.

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.web_server.aws_instance.main

# Move resource (rename in state)
terraform state mv \
  aws_instance.old \
  aws_instance.new

# Remove from state (not from AWS!)
terraform state rm aws_instance.legacy

# Pull state for inspection
terraform state pull > state-backup.json

# Import existing resource
terraform import aws_instance.existing i-0abc123
```

### When to Use:
- Emergency fixes
- State corruption
- Renaming resources
- Removing resources from management

### ⚠️ Warning:
Always backup state before manual manipulation:
```bash
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate
```

---

## Comparison Matrix

| Method | Safety | Ease | Use Case | Production Ready |
|--------|--------|------|----------|-----------------|
| **Separate States** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Long-term isolation | ✅ YES |
| **Plan Files** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | All deployments | ✅ YES |
| **Moved Blocks** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Refactoring | ✅ YES |
| **Import Blocks** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Adding existing | ✅ YES |
| **Workspaces** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Testing/dev | ⚠️ Limited |
| **Replace Flag** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Selective recreate | ✅ YES |
| **Lifecycle Rules** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Protection policies | ✅ YES |
| **State Commands** | ⭐⭐ | ⭐⭐ | Emergencies only | ❌ NO |
| **-target Flag** | ⭐⭐ | ⭐⭐⭐⭐⭐ | Emergencies only | ❌ NO |

---

## Recommended Workflow

### For New Projects:
1. ✅ **Start with separate state files** (networking, database, compute)
2. ✅ **Use plan files** for all applies
3. ✅ **Add lifecycle rules** to critical resources
4. ✅ **Use moved blocks** when refactoring

### For Existing Projects:
1. ✅ **Enable S3 state versioning** immediately
2. ✅ **Use plan files** going forward
3. ✅ **Gradually split into separate states**
4. ✅ **Add import blocks** for manual resources

### For Emergencies:
1. ⚠️ **-target flag** (last resort)
2. ⚠️ **state commands** (with backups)
3. ✅ **Workspace for testing fix**
4. ✅ **Plan file to apply fix**

---

## Enterprise CI/CD Example

```yaml
# .gitlab-ci.yml - Safe deployment pipeline

stages:
  - validate
  - plan
  - approve
  - apply

variables:
  TF_ROOT: projects/project-charan/dev/03-compute

validate:
  stage: validate
  script:
    - cd $TF_ROOT
    - terraform fmt -check -recursive
    - terraform validate
    - tfsec .

plan:
  stage: plan
  script:
    - cd $TF_ROOT
    - terraform plan -out=tfplan
    - terraform show tfplan > plan.txt
    - terraform show -json tfplan > plan.json
    - infracost breakdown --path plan.json
  artifacts:
    paths:
      - $TF_ROOT/tfplan
      - $TF_ROOT/plan.txt
      - $TF_ROOT/plan.json
    expire_in: 7 days

approve:
  stage: approve
  when: manual  # Requires human approval
  only:
    - main
  script:
    - echo "Plan approved by $GITLAB_USER_LOGIN"

apply:
  stage: apply
  needs:
    - validate
    - plan
    - approve
  only:
    - main
  script:
    - cd $TF_ROOT
    # Apply ONLY the approved plan
    - terraform apply tfplan
    # Tag deployment
    - git tag "deploy-$(date +%Y%m%d-%H%M%S)-$CI_COMMIT_SHORT_SHA"
  after_script:
    # Notify team
    - curl -X POST $SLACK_WEBHOOK -d "Deployment completed by $GITLAB_USER_LOGIN"
```

---

## Key Takeaways

1. **-target is NOT for production** - use only in emergencies
2. **Separate state files** = safest for complex infrastructure
3. **Plan files** = required for enterprise deployments
4. **Moved blocks** = refactor without recreation
5. **Import blocks** = adopt existing resources safely
6. **Lifecycle rules** = protect critical resources
7. **Always review plans** before applying

---

## Next Steps for Your Project

1. Split current state into components:
   ```bash
   cd projects/project-charan/dev
   mkdir 01-networking 02-database 03-compute
   ```

2. Enable versioning:
   ```bash
   aws s3api put-bucket-versioning \
     --bucket terraform-state-charan-492267476800 \
     --versioning-configuration Status=Enabled
   ```

3. Add lifecycle protection to RDS:
   ```hcl
   lifecycle {
     prevent_destroy = true
   }
   ```

4. Use plan files going forward:
   ```bash
   terraform plan -out=tfplan
   terraform show tfplan | less  # Review
   terraform apply tfplan        # Apply
   ```
