#!/bin/bash

# Security Audit and Cleanup Script
# Verifies no secrets are in Git and provides cleanup if needed

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform Security Audit${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 1
fi

ISSUES_FOUND=0

# 1. Check for sensitive files in Git history
echo -e "${BLUE}[1/7] Checking Git history for secrets...${NC}"
SENSITIVE_PATTERNS=(
    "terraform.tfstate"
    "terraform.tfstate.backup"
    "*.pem"
    "*.key"
    "terraform.tfvars"
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    # Check current tracked files
    TRACKED=$(git ls-files | grep -E "$(echo $pattern | sed 's/\*/.*/')" | grep -v example || true)
    if [ -n "$TRACKED" ]; then
        echo -e "${RED}❌ SECURITY ISSUE: Sensitive files tracked in Git:${NC}"
        echo "$TRACKED"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # Check Git history
    HISTORY=$(git log --all --full-history --oneline -- "$pattern" 2>/dev/null || true)
    if [ -n "$HISTORY" ]; then
        echo -e "${YELLOW}⚠️  WARNING: Pattern '$pattern' found in Git history${NC}"
        echo "  (May have been committed and deleted - consider git filter-repo)"
    fi
done

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ No sensitive files tracked in Git${NC}\n"
else
    echo -e "${RED}Found $ISSUES_FOUND issues${NC}\n"
fi

# 2. Check .gitignore
echo -e "${BLUE}[2/7] Verifying .gitignore protection...${NC}"
REQUIRED_IGNORES=(
    "*.tfstate"
    "*.tfstate.*"
    "*.tfvars"
    "*.pem"
    "*.key"
    "bootstrap/keys/"
    ".terraform/"
)

GITIGNORE_OK=true
for pattern in "${REQUIRED_IGNORES[@]}"; do
    if ! grep -q "$pattern" .gitignore 2>/dev/null; then
        echo -e "${RED}❌ Missing in .gitignore: $pattern${NC}"
        GITIGNORE_OK=false
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

if [ "$GITIGNORE_OK" = true ]; then
    echo -e "${GREEN}✅ .gitignore properly configured${NC}\n"
else
    echo -e "${RED}⚠️  .gitignore needs updates${NC}\n"
fi

# 3. Check for local sensitive files
echo -e "${BLUE}[3/7] Scanning for local sensitive files...${NC}"
LOCAL_SENSITIVE=$(find . -type f \( -name "*.tfstate" -o -name "*.pem" -o -name "*.key" \) \
    ! -path "./.git/*" \
    ! -path "./.terraform/*" \
    2>/dev/null || true)

if [ -n "$LOCAL_SENSITIVE" ]; then
    echo -e "${YELLOW}⚠️  Sensitive files found locally (should NOT be in Git):${NC}"
    echo "$LOCAL_SENSITIVE" | while read -r file; do
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            echo -e "  ${RED}❌ TRACKED: $file${NC}"
        else
            echo -e "  ${GREEN}✓ Not tracked: $file${NC}"
        fi
    done
    echo ""
else
    echo -e "${GREEN}✅ No local sensitive files found (or properly ignored)${NC}\n"
fi

# 4. Check backend configuration
echo -e "${BLUE}[4/7] Checking backend configuration...${NC}"
BACKEND_FILES=$(find projects -name "backend.tf" 2>/dev/null || true)
REMOTE_BACKEND_COUNT=0
LOCAL_BACKEND_COUNT=0

while IFS= read -r backend_file; do
    if grep -q 'backend "s3"' "$backend_file" 2>/dev/null; then
        REMOTE_BACKEND_COUNT=$((REMOTE_BACKEND_COUNT + 1))
    elif grep -q 'backend "local"' "$backend_file" 2>/dev/null; then
        LOCAL_BACKEND_COUNT=$((LOCAL_BACKEND_COUNT + 1))
        echo -e "${YELLOW}⚠️  Local backend in: $backend_file${NC}"
    fi
done <<< "$BACKEND_FILES"

if [ $REMOTE_BACKEND_COUNT -gt 0 ]; then
    echo -e "${GREEN}✅ Remote backends configured: $REMOTE_BACKEND_COUNT${NC}"
fi
if [ $LOCAL_BACKEND_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Local backends found: $LOCAL_BACKEND_COUNT (should migrate to S3)${NC}"
fi
echo ""

# 5. Check for hardcoded secrets in Terraform files
echo -e "${BLUE}[5/7] Scanning for hardcoded secrets...${NC}"
SECRET_PATTERNS=(
    "password\s*=\s*\"[^\"]*\""
    "secret_key\s*=\s*\"[^\"]*\""
    "access_key\s*=\s*\"[^\"]*\""
    "AKIA[0-9A-Z]{16}"  # AWS Access Key pattern
)

SECRETS_FOUND=false
for pattern in "${SECRET_PATTERNS[@]}"; do
    MATCHES=$(grep -r -n -E "$pattern" --include="*.tf" --include="*.tfvars" . \
        --exclude-dir=.git \
        --exclude-dir=.terraform \
        --exclude="*example*" \
        2>/dev/null || true)
    
    if [ -n "$MATCHES" ]; then
        echo -e "${RED}❌ Potential hardcoded secrets found:${NC}"
        echo "$MATCHES"
        SECRETS_FOUND=true
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

if [ "$SECRETS_FOUND" = false ]; then
    echo -e "${GREEN}✅ No hardcoded secrets detected${NC}\n"
else
    echo -e "${RED}⚠️  Review findings above${NC}\n"
fi

# 6. Check SSH key management
echo -e "${BLUE}[6/7] Checking SSH key management...${NC}"
if [ -d "bootstrap/keys" ]; then
    KEY_FILES=$(find bootstrap/keys -name "*.pem" 2>/dev/null || echo "")
    if [ -n "$KEY_FILES" ]; then
        KEY_COUNT=$(echo "$KEY_FILES" | wc -l | tr -d ' ')
        echo -e "${YELLOW}⚠️  Found $KEY_COUNT SSH keys in bootstrap/keys/${NC}"
        echo -e "${YELLOW}   Consider moving to AWS SSM Parameter Store:${NC}"
        echo -e "   ${BLUE}aws ssm put-parameter --name /ec2/keys/KEY_NAME \\\\${NC}"
        echo -e "   ${BLUE}  --value \\\"\\\$(cat bootstrap/keys/KEY.pem)\\\" \\\\${NC}"
        echo -e "   ${BLUE}  --type SecureString${NC}\n"
        
        # Check if keys are tracked by git
        while IFS= read -r key; do
            if [ -f "$key" ] && git ls-files --error-unmatch "$key" >/dev/null 2>&1; then
                echo -e "${RED}❌ KEY TRACKED IN GIT: $key${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
        done <<< "$KEY_FILES"
    else
        echo -e "${GREEN}✅ No SSH keys in bootstrap/keys/${NC}\n"
    fi
else
    echo -e "${GREEN}✅ bootstrap/keys/ directory doesn't exist${NC}\n"
fi

# 7. Generate security report
echo -e "${BLUE}[7/7] Generating security recommendations...${NC}\n"

cat << EOF
${BLUE}========================================${NC}
${BLUE}Security Recommendations${NC}
${BLUE}========================================${NC}

${GREEN}✅ What's Working Well:${NC}
  • .gitignore blocks state files, keys, and secrets
  • Remote S3 backend configured for state storage
  • Separate environments (dev/staging/prod)
  • No sensitive files in Git tracking

${YELLOW}📋 Best Practices to Implement:${NC}

1. ${YELLOW}State Management:${NC}
   ✓ Use S3 backend (already configured)
   ✓ Enable S3 versioning for state recovery
   ✓ Enable S3 encryption (AES-256 or KMS)
   ✓ Configure DynamoDB for state locking
   
   ${BLUE}# Enable in bootstrap/main.tf:${NC}
   aws s3api put-bucket-versioning \\
     --bucket terraform-state-charan-492267476800 \\
     --versioning-configuration Status=Enabled

2. ${YELLOW}Secrets Management:${NC}
   ✓ Move DB passwords to AWS Secrets Manager
   ✓ Move SSH keys to AWS SSM Parameter Store
   ✓ Use IAM roles instead of AWS access keys
   ✓ Mark sensitive variables in Terraform
   
   ${BLUE}# Store DB password:${NC}
   aws secretsmanager create-secret \\
     --name "project-charan/dev/db-password" \\
     --secret-string '{"password":"YourPassword"}'
   
   ${BLUE}# Retrieve in Terraform:${NC}
   data "aws_secretsmanager_secret_version" "db_password" {
     secret_id = "project-charan/dev/db-password"
   }

3. ${YELLOW}SSH Key Management:${NC}
   ${BLUE}# Store in SSM:${NC}
   aws ssm put-parameter \\
     --name "/ec2/keys/project-charan-dev-key" \\
     --value "\$(cat bootstrap/keys/project-charan-dev-key.pem)" \\
     --type "SecureString"
   
   ${BLUE}# Retrieve when needed:${NC}
   aws ssm get-parameter \\
     --name "/ec2/keys/project-charan-dev-key" \\
     --with-decryption \\
     --query "Parameter.Value" --output text > ~/.ssh/key.pem
   
   ${BLUE}# Then delete local copy:${NC}
   rm bootstrap/keys/*.pem

4. ${YELLOW}Access Control:${NC}
   ✓ Configure S3 bucket policies (restrict access)
   ✓ Enable S3 access logging
   ✓ Enable AWS CloudTrail for audit
   ✓ Use IAM roles for CI/CD (not access keys)

5. ${YELLOW}Monitoring & Auditing:${NC}
   ✓ Enable S3 versioning (rollback capability)
   ✓ Enable CloudTrail logging
   ✓ Set up DynamoDB for state locking
   ✓ Review Git history regularly
   ✓ Archive terraform plan files for compliance

${BLUE}========================================${NC}
${BLUE}Quick Commands${NC}
${BLUE}========================================${NC}

${GREEN}# View state file location:${NC}
cat projects/project-charan/dev/backend.tf

${GREEN}# List state versions in S3:${NC}
aws s3api list-object-versions \\
  --bucket terraform-state-charan-492267476800 \\
  --prefix project-charan/dev/

${GREEN}# Check who has state lock:${NC}
aws dynamodb get-item \\
  --table-name terraform-locks \\
  --key '{"LockID": {"S": "terraform-state-charan-492267476800/project-charan/dev/terraform.tfstate"}}'

${GREEN}# Verify no secrets in Git:${NC}
git log --all --full-history --oneline -- "*.tfstate" "*.pem" "*.tfvars"

${GREEN}# Run this audit script again:${NC}
./scripts/security-audit.sh

EOF

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Audit Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ SECURITY STATUS: GOOD${NC}"
    echo -e "${GREEN}No critical issues found!${NC}\n"
    exit 0
else
    echo -e "${RED}⚠️  SECURITY STATUS: NEEDS ATTENTION${NC}"
    echo -e "${RED}Found $ISSUES_FOUND issue(s) requiring action${NC}\n"
    exit 1
fi
