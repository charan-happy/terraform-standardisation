#!/bin/bash
# Terraform Setup Script
# This script helps you set up the Terraform environment

set -e  # Exit on error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Terraform Infrastructure Setup"
echo "=================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check version
check_terraform_version() {
    local version=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    local required="1.7.0"
    
    if [ "$(printf '%s\n' "$required" "$version" | sort -V | head -n1)" = "$required" ]; then 
        return 0
    else
        return 1
    fi
}

echo "📋 Checking prerequisites..."
echo ""

# Check Terraform
if command_exists terraform; then
    if check_terraform_version; then
        echo -e "${GREEN}✓${NC} Terraform >= 1.7.0 installed"
    else
        echo -e "${RED}✗${NC} Terraform version too old (need >= 1.7.0)"
        echo "  Run: brew upgrade terraform"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Terraform not installed"
    echo "  Run: brew install terraform"
    exit 1
fi

# Check AWS CLI
if command_exists aws; then
    echo -e "${GREEN}✓${NC} AWS CLI installed"
else
    echo -e "${YELLOW}⚠${NC}  AWS CLI not found"
    echo "  Run: brew install awscli"
fi

# Check pre-commit
if command_exists pre-commit; then
    echo -e "${GREEN}✓${NC} pre-commit installed"
else
    echo -e "${YELLOW}⚠${NC}  pre-commit not found"
    echo "  Run: brew install pre-commit"
fi

# Check tflint
if command_exists tflint; then
    echo -e "${GREEN}✓${NC} tflint installed"
else
    echo -e "${YELLOW}⚠${NC}  tflint not found"
    echo "  Run: brew install tflint"
fi

# Check tfsec
if command_exists tfsec; then
    echo -e "${GREEN}✓${NC} tfsec installed"
else
    echo -e "${YELLOW}⚠${NC}  tfsec not found"
    echo "  Run: brew install tfsec"
fi

echo ""
echo "🔧 Setting up Git hooks..."

# Install pre-commit hooks
if command_exists pre-commit; then
    pre-commit install
    echo -e "${GREEN}✓${NC} Pre-commit hooks installed"
else
    echo -e "${YELLOW}⚠${NC}  Skipping pre-commit setup (not installed)"
fi

# Initialize tflint
if command_exists tflint; then
    tflint --init
    echo -e "${GREEN}✓${NC} tflint initialized"
else
    echo -e "${YELLOW}⚠${NC}  Skipping tflint setup (not installed)"
fi

echo ""
echo "📂 Checking directory structure..."

# Check for directory typo
if [ -d "projecdts" ]; then
    echo -e "${RED}✗${NC} Found 'projecdts' directory (typo)"
    read -p "Rename to 'projects'? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -d "projects" ]; then
            echo -e "${RED}✗${NC} Both 'projecdts' and 'projects' exist. Please resolve manually."
        else
            mv projecdts projects
            echo -e "${GREEN}✓${NC} Renamed projecdts -> projects"
        fi
    fi
elif [ -d "projects" ]; then
    echo -e "${GREEN}✓${NC} Projects directory exists"
else
    echo -e "${RED}✗${NC} No projects directory found"
fi

echo ""
echo "☁️  AWS Configuration Check..."

# Check AWS credentials
if command_exists aws; then
    if aws sts get-caller-identity >/dev/null 2>&1; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        echo -e "${GREEN}✓${NC} AWS credentials configured (Account: $ACCOUNT_ID)"
    else
        echo -e "${YELLOW}⚠${NC}  AWS credentials not configured"
        echo "  Run: aws configure"
    fi
fi

echo ""
echo "📝 Next Steps:"
echo "============="
echo ""
echo "1. Update backend configuration:"
echo "   - Edit backend-config/*.hcl files"
echo "   - Replace 'your-terraform-state-bucket' with actual bucket name"
echo ""
echo "2. Create AWS resources:"
echo "   - S3 bucket for state storage"
echo "   - DynamoDB table for locking"
echo "   - EC2 key pair"
echo ""
echo "3. Create terraform.tfvars:"
echo "   cd projects/project-charan/dev"
echo "   cp terraform.tfvars.example terraform.tfvars"
echo "   # Edit terraform.tfvars with your values"
echo ""
echo "4. Initialize Terraform:"
echo "   cd projects/project-charan/dev"
echo "   terraform init"
echo ""
echo "5. Validate and plan:"
echo "   terraform fmt -recursive"
echo "   terraform validate"
echo "   terraform plan"
echo ""
echo -e "${GREEN}Setup complete!${NC} 🎉"
echo ""
echo "For detailed instructions, see:"
echo "  - docs/SETUP_CHECKLIST.md"
echo "  - docs/QUICK_START.md"
echo "  - docs/TROUBLESHOOTING.md"
