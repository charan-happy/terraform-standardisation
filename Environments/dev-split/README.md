# Split State Infrastructure

This directory demonstrates the **recommended enterprise pattern** of splitting infrastructure into separate state files.

## Structure

```
dev-split/
├── 01-networking/     # VPC, Subnets (foundation)
├── 02-database/       # RDS (critical data)
└── 03-compute/        # EC2, ALB (frequent changes)
```

## Benefits

✅ **Isolation**: Changes to compute cannot affect database
✅ **Speed**: Smaller state = faster plan/apply
✅ **Security**: Different IAM permissions per layer
✅ **Team Ownership**: Different teams own different layers
✅ **Rollback**: Easy to rollback specific layers

## Deployment Order

### Initial Setup

```bash
# 1. Deploy networking (foundation)
cd 01-networking
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 2. Deploy database (depends on networking)
cd ../02-database
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 3. Deploy compute (depends on both)
cd ../03-compute
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Adding New EC2 Instance

Since compute has its own state, you can modify it **without risk** to networking or database:

```bash
cd 03-compute

# Edit main.tf to add new instance
vim main.tf

# Plan and apply - ONLY affects compute
terraform plan -out=tfplan
terraform apply tfplan
```

### Rolling Back Changes

If compute deployment fails, networking and database are **unaffected**:

```bash
cd 03-compute

# Restore previous state version
aws s3api get-object \
  --bucket terraform-state-charan-492267476800 \
  --key project-charan/dev/compute/terraform.tfstate \
  --version-id PREVIOUS_VERSION_ID \
  terraform.tfstate

terraform apply
```

## Data Flow

Layers communicate via `terraform_remote_state`:

```
01-networking (outputs)
    ↓
    ├─> 02-database (reads networking outputs)
    │       ↓
    └─> 03-compute (reads networking + database outputs)
```

## Example: Adding ALB (Safe!)

```bash
cd 03-compute

# Add ALB module to main.tf
cat >> main.tf <<'EOF'

# Application Load Balancer
module "alb" {
  source = "../../../../modules/alb"
  
  name       = "${var.project_name}-alb"
  vpc_id     = data.terraform_remote_state.networking.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.networking.outputs.public_subnet_ids
  # ... config
}
EOF

# Plan and apply - networking and database untouched!
terraform plan -out=tfplan
terraform apply tfplan
```

## Migration from Single State

To migrate your existing `dev/` infrastructure:

```bash
# 1. Backup current state
cd projects/project-charan/dev
terraform state pull > backup-all.tfstate

# 2. Initialize new structure
cd ../dev-split/01-networking
terraform init

# 3. Import existing resources
terraform import module.vpc.aws_vpc.main vpc-0ea572fbb659286db
# ... import other networking resources

# 4. Repeat for database and compute layers

# 5. Verify with plan (should show no changes)
terraform plan

# 6. Remove old state reference once confirmed
```

## State File Locations

- **Networking**: `s3://terraform-state-charan-492267476800/project-charan/dev/networking/terraform.tfstate`
- **Database**: `s3://terraform-state-charan-492267476800/project-charan/dev/database/terraform.tfstate`
- **Compute**: `s3://terraform-state-charan-492267476800/project-charan/dev/compute/terraform.tfstate`

## Best Practices

1. **Always use plan files**: `terraform plan -out=tfplan && terraform apply tfplan`
2. **Deploy in order**: networking → database → compute
3. **Review remote state**: Check what outputs are available before using
4. **Version outputs**: Document what outputs each layer provides
5. **Protect critical layers**: Add `prevent_destroy` to database resources

## Troubleshooting

### "No matching state" error in compute
**Problem**: Networking not deployed yet
**Solution**: Deploy networking first: `cd 01-networking && terraform apply`

### "Failed to read remote state" error
**Problem**: State bucket not initialized
**Solution**: Check backend configuration and bucket exists

### Circular dependency
**Problem**: Two layers trying to read each other's outputs
**Solution**: Restructure - dependencies should flow one direction only
