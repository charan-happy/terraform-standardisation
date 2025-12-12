#!/bin/bash
# AWS Backend Setup Script
# Creates S3 bucket and DynamoDB table for Terraform state

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "☁️  AWS Terraform Backend Setup"
echo "=============================="
echo ""

# Check AWS CLI
if ! command -v aws >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} AWS CLI not installed"
    echo "Run: brew install awscli"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓${NC} AWS Account: $ACCOUNT_ID"
echo ""

# Get inputs
read -p "Enter AWS region [us-east-1]: " REGION
REGION=${REGION:-us-east-1}

read -p "Enter unique identifier for bucket (e.g., your-company): " IDENTIFIER
if [ -z "$IDENTIFIER" ]; then
    echo -e "${RED}✗${NC} Identifier is required"
    exit 1
fi

BUCKET_NAME="terraform-state-${IDENTIFIER}-${ACCOUNT_ID}"
TABLE_NAME="terraform-locks"

echo ""
echo "Configuration:"
echo "  Region: $REGION"
echo "  Bucket: $BUCKET_NAME"
echo "  Table:  $TABLE_NAME"
echo ""

read -p "Create these resources? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "🪣  Creating S3 bucket..."

# Create bucket
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC}  Bucket already exists: $BUCKET_NAME"
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
    else
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo -e "${GREEN}✓${NC} Bucket created: $BUCKET_NAME"
fi

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$REGION"
echo -e "${GREEN}✓${NC} Versioning enabled"

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    --region "$REGION"
echo -e "${GREEN}✓${NC} Encryption enabled"

# Block public access
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
    --region "$REGION"
echo -e "${GREEN}✓${NC} Public access blocked"

echo ""
echo "📊 Creating DynamoDB table..."

# Create DynamoDB table
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  Table already exists: $TABLE_NAME"
else
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" >/dev/null
    
    echo -e "${BLUE}⏳${NC} Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
    echo -e "${GREEN}✓${NC} Table created: $TABLE_NAME"
fi

echo ""
echo "🔑 Creating EC2 key pair (optional)..."
read -p "Create EC2 key pair? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter key pair name [project-charan-dev-key]: " KEY_NAME
    KEY_NAME=${KEY_NAME:-project-charan-dev-key}
    
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC}  Key pair already exists: $KEY_NAME"
    else
        aws ec2 create-key-pair \
            --key-name "$KEY_NAME" \
            --query 'KeyMaterial' \
            --output text \
            --region "$REGION" > "$HOME/.ssh/${KEY_NAME}.pem"
        
        chmod 400 "$HOME/.ssh/${KEY_NAME}.pem"
        echo -e "${GREEN}✓${NC} Key pair created: $KEY_NAME"
        echo "   Saved to: $HOME/.ssh/${KEY_NAME}.pem"
    fi
fi

echo ""
echo "📝 Updating configuration files..."
echo ""

# Update backend config files
for env in dev staging prod; do
    CONFIG_FILE="backend-config/${env}.hcl"
    if [ -f "$CONFIG_FILE" ]; then
        sed -i.bak "s/your-terraform-state-bucket/$BUCKET_NAME/g" "$CONFIG_FILE"
        sed -i.bak "s/region.*=.*/region         = \"$REGION\"/g" "$CONFIG_FILE"
        rm "${CONFIG_FILE}.bak"
        echo -e "${GREEN}✓${NC} Updated $CONFIG_FILE"
    fi
done

# Update project backend.tf
BACKEND_FILE="projects/project-charan/dev/backend.tf"
if [ -f "$BACKEND_FILE" ]; then
    sed -i.bak "s/your-terraform-state-bucket/$BUCKET_NAME/g" "$BACKEND_FILE"
    sed -i.bak "s/region.*=.*/    region         = \"$REGION\"/g" "$BACKEND_FILE"
    rm "${BACKEND_FILE}.bak"
    echo -e "${GREEN}✓${NC} Updated $BACKEND_FILE"
fi

echo ""
echo -e "${GREEN}✓✓✓ Backend setup complete!${NC} 🎉"
echo ""
echo "Configuration:"
echo "  S3 Bucket:      $BUCKET_NAME"
echo "  DynamoDB Table: $TABLE_NAME"
echo "  Region:         $REGION"
echo ""
echo "Next steps:"
echo "  1. cd projects/project-charan/dev"
echo "  2. cp terraform.tfvars.example terraform.tfvars"
echo "  3. Edit terraform.tfvars with your values"
echo "  4. terraform init"
echo "  5. terraform plan"
