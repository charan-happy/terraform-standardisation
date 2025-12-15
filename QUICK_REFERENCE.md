# Quick Reference Guide - Deployment Methods

## 🎯 Quick Commands

### 1. Deploy with Plan File (RECOMMENDED)
```bash
./scripts/deploy-with-plan.sh dev
```

### 2. Deploy with Workspace (Testing)
```bash
./scripts/deploy-with-workspace.sh feature-alb
```

### 3. Replace Specific Resource
```bash
./scripts/replace-resource.sh module.web_server.aws_instance.main[0]
```

### 4. State Management
```bash
# List all resources
./scripts/state-management.sh list

# Show specific resource
./scripts/state-management.sh show aws_instance.web[0]

# Rename resource
./scripts/state-management.sh mv aws_instance.old aws_instance.new

# Remove from state (doesn't delete from AWS)
./scripts/state-management.sh rm aws_instance.legacy

# Import existing resource
./scripts/state-management.sh import aws_instance.existing i-0abc123

# Backup state
./scripts/state-management.sh backup
```

---

## 📁 Files Created

### Scripts (`scripts/`)
- **deploy-with-plan.sh** - Safe deployment using plan files
- **deploy-with-workspace.sh** - Workspace-based testing
- **replace-resource.sh** - Force recreate specific resources
- **state-management.sh** - State manipulation commands

### Examples (`examples/`)
- **moved-blocks.tf** - Examples of renaming/refactoring
- **import-blocks.tf** - Examples of importing existing resources
- **lifecycle-rules.tf** - Protection and management rules

### CI/CD Pipelines
- **.gitlab-ci.yml** - GitLab CI/CD pipeline
- **.github/workflows/terraform.yml** - GitHub Actions workflow

---

## 🚀 Common Workflows

### Adding New EC2 Instance (Safe)
```bash
# 1. Edit main.tf to add new module
vim projects/project-charan/dev/main.tf

# 2. Deploy with plan
./scripts/deploy-with-plan.sh dev

# Existing resources: SAFE ✅
```

### Testing Changes Before Production
```bash
# 1. Create test workspace
./scripts/deploy-with-workspace.sh test-changes

# 2. Make your changes
vim main.tf

# 3. Apply to test workspace
./scripts/deploy-with-plan.sh dev

# 4. If successful, merge and deploy to prod
terraform workspace select default
./scripts/deploy-with-plan.sh prod
```

### Renaming Resource (No Downtime)
```bash
# 1. Add moved block to main.tf
cat >> main.tf <<EOF
moved {
  from = module.server
  to   = module.web_server
}
EOF

# 2. Update module name
vim main.tf  # Change module "server" to module "web_server"

# 3. Apply (no recreation!)
./scripts/deploy-with-plan.sh dev
```

### Importing Existing Resource
```bash
# 1. Add import block (see examples/import-blocks.tf)
# 2. Add resource configuration
# 3. Apply
./scripts/deploy-with-plan.sh dev
```

### Recreating Unhealthy Instance
```bash
# Replace specific instance
./scripts/replace-resource.sh module.web_server.aws_instance.main[0]
```

---

## 🔒 Safety Checklist

Before deploying to production:

- [ ] ✅ Code reviewed by 2+ people
- [ ] ✅ `terraform fmt` passed
- [ ] ✅ `terraform validate` passed
- [ ] ✅ Plan reviewed and approved
- [ ] ✅ No unintended resource destruction
- [ ] ✅ Backups created
- [ ] ✅ Rollback plan ready
- [ ] ✅ Team notified
- [ ] ✅ Monitoring enabled

---

## 🎓 Learning Path

1. **Start here**: Use `deploy-with-plan.sh` for all deployments
2. **Next**: Try workspace testing with `deploy-with-workspace.sh`
3. **Advanced**: Use moved blocks for refactoring (see `examples/moved-blocks.tf`)
4. **Expert**: Direct state management with `state-management.sh` (CAREFUL!)

---

## 🆘 Emergency Procedures

### Rollback Deployment
```bash
# 1. List state versions
aws s3api list-object-versions \
  --bucket terraform-state-charan-492267476800 \
  --prefix project-charan/dev/terraform.tfstate

# 2. Restore previous version
./scripts/state-management.sh pull
# Edit state file
./scripts/state-management.sh push state-backup-TIMESTAMP.tfstate
```

### Remove Bad Resource
```bash
# 1. Remove from state (doesn't delete from AWS)
./scripts/state-management.sh rm aws_instance.bad

# 2. Manually delete from AWS console

# 3. Remove from Terraform config
vim main.tf

# 4. Apply
./scripts/deploy-with-plan.sh dev
```

---

## 📚 Documentation

Detailed guides:
- [SAFE_DEPLOYMENT_ALTERNATIVES.md](docs/SAFE_DEPLOYMENT_ALTERNATIVES.md)
- [ENTERPRISE_PRACTICES.md](docs/ENTERPRISE_PRACTICES.md)
- [dev-split/README.md](projects/project-charan/dev-split/README.md)

---

## 💡 Pro Tips

1. **Always use plan files** - Never run `terraform apply` without reviewing plan first
2. **Test in workspaces** - Try changes in isolated workspace before production
3. **Use moved blocks** - Rename/refactor without recreation
4. **Protect critical resources** - Add `lifecycle { prevent_destroy = true }`
5. **Separate states** - Use split structure (networking, database, compute)
6. **Backup before state changes** - `./scripts/state-management.sh backup`
7. **Tag deployments** - Scripts auto-tag git commits
8. **Review diffs** - Check plan output carefully before apply

---

## ⚡ Quick Examples

```bash
# Safe deployment
./scripts/deploy-with-plan.sh dev

# Test in workspace
./scripts/deploy-with-workspace.sh feature-test

# Replace bad instance
./scripts/replace-resource.sh aws_instance.web[0]

# List all resources
./scripts/state-management.sh list

# Backup state
./scripts/state-management.sh backup

# Import existing
./scripts/state-management.sh import aws_instance.existing i-abc123
```

---

## 🎯 Remember

**Never use `-target` in production!**

Use these methods instead:
1. ✅ Separate state files (best isolation)
2. ✅ Plan files (required for all deployments)
3. ✅ Workspaces (for testing)
4. ✅ Moved blocks (for refactoring)
5. ✅ Replace flag (for recreation)
