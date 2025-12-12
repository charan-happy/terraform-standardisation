#!/bin/bash
# Quick Bootstrap Script
# Creates all backend infrastructure with one command

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🚀 Terraform Backend Bootstrap"
echo "=============================="
echo ""

# Check if we're in the bootstrap directory
if [ ! -f "main.tf" ]; then
    echo -e "${RED}✗${NC} Please run this script from the bootstrap directory"
    echo "  cd bootstrap && ./bootstrap.sh"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} AWS credentials not configured"
    echo "  Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓${NC} AWS Account: $ACCOUNT_ID"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠${NC}  terraform.tfvars not found"
    echo "  Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${GREEN}✓${NC} Created terraform.tfvars"
    echo ""
    echo -e "${BLUE}ℹ${NC}  Review and edit terraform.tfvars if needed"
    read -p "Continue with default values? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Edit terraform.tfvars and run this script again"
        exit 0
    fi
fi

echo "📦 Initializing Terraform..."
terraform init
echo ""

echo "📋 Planning infrastructure..."
terraform plan -out=bootstrap.tfplan
echo ""

echo -e "${YELLOW}⚠${NC}  Review the plan above"
read -p "Create these resources? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    rm -f bootstrap.tfplan
    exit 0
fi

echo ""
echo "🏗️  Creating backend infrastructure..."
terraform apply bootstrap.tfplan
rm -f bootstrap.tfplan
echo ""

echo -e "${GREEN}✓✓✓ Bootstrap Complete!${NC} 🎉"
echo ""
echo "📁 Private keys saved to: bootstrap/keys/"
echo "   Don't forget to secure them!"
echo ""
echo "Next steps:"
echo "  1. cd ../projects/project-charan/dev"
echo "  2. Add db_password to terraform.tfvars"
echo "  3. terraform init"
echo "  4. terraform plan"
echo "  5. terraform apply"
