#!/bin/bash

# CI/CD Setup Script for Terraform POC
# Quickly set up GitHub Actions or GitLab CI/CD

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Terraform CI/CD Setup Script                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}\n"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 1
fi

# Ask which CI/CD platform
echo -e "${YELLOW}Which CI/CD platform are you using?${NC}"
echo "1) GitHub Actions"
echo "2) GitLab CI/CD"
echo "3) Both"
read -p "Enter choice (1-3): " PLATFORM

# Get project details
echo -e "\n${YELLOW}Project Configuration:${NC}"
read -p "AWS Region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "AWS Account ID: " AWS_ACCOUNT_ID
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ AWS Account ID is required${NC}"
    exit 1
fi

read -p "Terraform project path (default: projects/project-charan/dev): " TF_PROJECT_PATH
TF_PROJECT_PATH=${TF_PROJECT_PATH:-projects/project-charan/dev}

read -p "Required approvers count (default: 2): " APPROVERS_COUNT
APPROVERS_COUNT=${APPROVERS_COUNT:-2}

# GitHub Actions Setup
if [ "$PLATFORM" == "1" ] || [ "$PLATFORM" == "3" ]; then
    echo -e "\n${BLUE}[1/5] Creating GitHub Actions workflows...${NC}"
    
    mkdir -p .github/workflows
    
    # Create PR workflow
    cat > .github/workflows/terraform-pr.yml << 'EOF'
name: Terraform PR Review

on:
  pull_request:
    branches: [main]
    paths:
      - 'projects/**/*.tf'
      - 'modules/**/*.tf'

permissions:
  contents: read
  pull-requests: write
  id-token: write

env:
  TF_VERSION: 1.7.0

jobs:
  validate:
    name: 🔍 Validate & Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
      - name: Format Check
        run: terraform fmt -check -recursive
      - name: Validate
        working-directory: TF_PROJECT_PATH
        run: |
          terraform init -backend=false
          terraform validate

  plan:
    name: 📋 Terraform Plan
    runs-on: ubuntu-latest
    needs: [validate]
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::AWS_ACCOUNT_ID:role/github-actions-terraform
          aws-region: AWS_REGION
      - name: Init & Plan
        working-directory: TF_PROJECT_PATH
        run: |
          terraform init
          terraform plan -out=tfplan | tee plan.txt
      - name: Post Plan Comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('TF_PROJECT_PATH/plan.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## 📋 Terraform Plan\n\`\`\`terraform\n${plan}\n\`\`\``
            });
EOF
    
    # Replace placeholders
    sed -i '' "s|AWS_ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" .github/workflows/terraform-pr.yml 2>/dev/null || \
        sed -i "s|AWS_ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" .github/workflows/terraform-pr.yml
    sed -i '' "s|AWS_REGION|${AWS_REGION}|g" .github/workflows/terraform-pr.yml 2>/dev/null || \
        sed -i "s|AWS_REGION|${AWS_REGION}|g" .github/workflows/terraform-pr.yml
    sed -i '' "s|TF_PROJECT_PATH|${TF_PROJECT_PATH}|g" .github/workflows/terraform-pr.yml 2>/dev/null || \
        sed -i "s|TF_PROJECT_PATH|${TF_PROJECT_PATH}|g" .github/workflows/terraform-pr.yml
    
    echo -e "${GREEN}✅ Created .github/workflows/terraform-pr.yml${NC}"
    
    # Create deploy workflow
    cat > .github/workflows/terraform-deploy.yml << 'EOF'
name: Terraform Deploy

on:
  push:
    branches: [main]
    paths:
      - 'projects/**/*.tf'
      - 'modules/**/*.tf'

permissions:
  contents: read
  id-token: write

env:
  TF_VERSION: 1.7.0

jobs:
  deploy:
    name: 🚀 Deploy
    runs-on: ubuntu-latest
    environment: development
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::AWS_ACCOUNT_ID:role/github-actions-terraform
          aws-region: AWS_REGION
      - name: Deploy
        working-directory: TF_PROJECT_PATH
        run: |
          terraform init
          terraform plan -out=tfplan
          terraform apply -auto-approve tfplan
EOF
    
    sed -i '' "s|AWS_ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" .github/workflows/terraform-deploy.yml 2>/dev/null || \
        sed -i "s|AWS_ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" .github/workflows/terraform-deploy.yml
    sed -i '' "s|AWS_REGION|${AWS_REGION}|g" .github/workflows/terraform-deploy.yml 2>/dev/null || \
        sed -i "s|AWS_REGION|${AWS_REGION}|g" .github/workflows/terraform-deploy.yml
    sed -i '' "s|TF_PROJECT_PATH|${TF_PROJECT_PATH}|g" .github/workflows/terraform-deploy.yml 2>/dev/null || \
        sed -i "s|TF_PROJECT_PATH|${TF_PROJECT_PATH}|g" .github/workflows/terraform-deploy.yml
    
    echo -e "${GREEN}✅ Created .github/workflows/terraform-deploy.yml${NC}"
    
    # Create PR template
    echo -e "\n${BLUE}[2/5] Creating PR template...${NC}"
    cat > .github/pull_request_template.md << 'EOF'
## 📋 Infrastructure Change Request

### Summary
<!-- Brief description of what infrastructure is being changed and why -->

### Resources Changed
- [ ] VPC
- [ ] EC2 Instances
- [ ] RDS Database
- [ ] Security Groups
- [ ] Other: ___________

### Environment
- [ ] Development
- [ ] Staging
- [ ] Production

### Testing
- [ ] Ran `terraform fmt`
- [ ] Ran `terraform validate`
- [ ] Ran `terraform plan` locally
- [ ] Reviewed plan output
- [ ] No unexpected deletions

### Rollback Plan
<!-- How to rollback if something goes wrong -->

### Related Issues
Closes #___

---
<!-- Terraform plan will be posted automatically by CI/CD -->
EOF
    echo -e "${GREEN}✅ Created .github/pull_request_template.md${NC}"
    
    # Create CODEOWNERS
    echo -e "\n${BLUE}[3/5] Creating CODEOWNERS file...${NC}"
    cat > .github/CODEOWNERS << 'EOF'
# Terraform Infrastructure Code Owners
# All .tf files require approval from platform team

*.tf @platform-team
projects/** @platform-team
modules/** @platform-team

# Production changes require additional approval
projects/**/prod/** @platform-team @sre-team @security-team
EOF
    echo -e "${GREEN}✅ Created .github/CODEOWNERS${NC}"
    echo -e "${YELLOW}⚠️  Update team names in .github/CODEOWNERS${NC}"
fi

# GitLab CI/CD Setup
if [ "$PLATFORM" == "2" ] || [ "$PLATFORM" == "3" ]; then
    echo -e "\n${BLUE}[4/5] Creating GitLab CI/CD configuration...${NC}"
    
    cat > .gitlab-ci.yml << 'EOF'
stages:
  - validate
  - plan
  - deploy

variables:
  TF_VERSION: "1.7.0"
  TF_ROOT: TF_PROJECT_PATH
  AWS_REGION: AWS_REGION

validate:
  stage: validate
  image: hashicorp/terraform:${TF_VERSION}
  script:
    - terraform fmt -check -recursive
    - cd ${TF_ROOT}
    - terraform init -backend=false
    - terraform validate
  only:
    - merge_requests
    - main

plan:
  stage: plan
  image: hashicorp/terraform:${TF_VERSION}
  before_script:
    - cd ${TF_ROOT}
    - terraform init
  script:
    - terraform plan -out=tfplan
    - terraform show tfplan > plan.txt
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
      - ${TF_ROOT}/plan.txt
    expire_in: 7 days
  only:
    - merge_requests

deploy:
  stage: deploy
  image: hashicorp/terraform:${TF_VERSION}
  before_script:
    - cd ${TF_ROOT}
    - terraform init
  script:
    - terraform apply -auto-approve
  environment:
    name: development
  only:
    - main
  when: manual
EOF
    
    sed -i '' "s|TF_PROJECT_PATH|${TF_PROJECT_PATH}|g" .gitlab-ci.yml 2>/dev/null || \
        sed -i "s|TF_PROJECT_PATH|${TF_PROJECT_PATH}|g" .gitlab-ci.yml
    sed -i '' "s|AWS_REGION|${AWS_REGION}|g" .gitlab-ci.yml 2>/dev/null || \
        sed -i "s|AWS_REGION|${AWS_REGION}|g" .gitlab-ci.yml
    
    echo -e "${GREEN}✅ Created .gitlab-ci.yml${NC}"
    
    # Create GitLab CODEOWNERS
    mkdir -p .gitlab
    cat > .gitlab/CODEOWNERS << 'EOF'
# Terraform Infrastructure Code Owners
*.tf @platform-team
projects/** @platform-team
modules/** @platform-team
EOF
    echo -e "${GREEN}✅ Created .gitlab/CODEOWNERS${NC}"
fi

# Summary
echo -e "\n${BLUE}[5/5] Setup Complete!${NC}\n"

cat << EOF
${GREEN}╔═══════════════════════════════════════════════════════╗${NC}
${GREEN}║   ✅ CI/CD Configuration Created                      ║${NC}
${GREEN}╚═══════════════════════════════════════════════════════╝${NC}

${YELLOW}📁 Files Created:${NC}
EOF

if [ "$PLATFORM" == "1" ] || [ "$PLATFORM" == "3" ]; then
    echo "  ✓ .github/workflows/terraform-pr.yml"
    echo "  ✓ .github/workflows/terraform-deploy.yml"
    echo "  ✓ .github/pull_request_template.md"
    echo "  ✓ .github/CODEOWNERS"
fi

if [ "$PLATFORM" == "2" ] || [ "$PLATFORM" == "3" ]; then
    echo "  ✓ .gitlab-ci.yml"
    echo "  ✓ .gitlab/CODEOWNERS"
fi

cat << EOF

${YELLOW}🔧 Next Steps:${NC}

${BLUE}1. Commit and push the changes:${NC}
   git add .github/ .gitlab-ci.yml .gitlab/ 2>/dev/null
   git commit -m "Add CI/CD pipelines for Terraform"
   git push origin main

${BLUE}2. Configure AWS OIDC for GitHub Actions:${NC}
   See: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

${BLUE}3. Set up branch protection (GitHub):${NC}
   - Go to: Settings → Branches → Add Rule
   - Branch: main
   - Enable:
     ✓ Require status checks (terraform/plan)
     ✓ Require ${APPROVERS_COUNT} approvals
     ✓ Dismiss stale reviews
     ✓ Require review from Code Owners

${BLUE}4. Set up protected branches (GitLab):${NC}
   - Go to: Settings → Repository → Protected Branches
   - Branch: main
   - Allowed to merge: Maintainers only
   - Required approvals: ${APPROVERS_COUNT}

${BLUE}5. Update CODEOWNERS:${NC}
   - Replace @platform-team with actual team names
   - Add specific team members if needed

${BLUE}6. Test the workflow:${NC}
   git checkout -b test/cicd
   echo "# test" >> README.md
   git commit -am "Test CI/CD pipeline"
   git push origin test/cicd
   # Create PR and watch automation! 🎉

${GREEN}✅ Setup complete! Your Terraform changes will now go through automated validation, security scanning, and approval workflows.${NC}

${YELLOW}For detailed documentation, see:${NC}
  📄 CICD_PR_APPROVAL_GUIDE.md

${YELLOW}Questions?${NC}
  Check the troubleshooting section in the guide above.

EOF
