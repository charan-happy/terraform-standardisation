#!/bin/bash
# Replace specific resources (force recreation)
# Usage: ./replace-resource.sh <resource-address>

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <resource-address> [resource-address2 ...]"
    echo ""
    echo "Examples:"
    echo "  $0 module.web_server.aws_instance.main[0]"
    echo "  $0 aws_instance.web[0] aws_instance.web[1]"
    echo ""
    echo "This will recreate the specified resource(s)."
    echo "Use this when:"
    echo "  - Instance is unhealthy"
    echo "  - Need to apply user_data changes"
    echo "  - Testing disaster recovery"
    echo ""
    echo "Available resources:"
    terraform state list
    exit 1
fi

echo "🔄 Terraform Resource Replacement"
echo "=================================="
echo ""

# Build replace flags
REPLACE_FLAGS=""
for RESOURCE in "$@"; do
    # Verify resource exists
    if ! terraform state list | grep -q "^${RESOURCE}$"; then
        echo "❌ Error: Resource not found: $RESOURCE"
        echo ""
        echo "Available resources:"
        terraform state list
        exit 1
    fi
    
    REPLACE_FLAGS="$REPLACE_FLAGS -replace=$RESOURCE"
    echo "📌 Will replace: $RESOURCE"
done

echo ""
echo "⚠️  This will destroy and recreate the specified resource(s)!"
echo ""

# Show plan with replace
echo "📋 Generating replacement plan..."
PLAN_FILE="tfplan-replace-$(date +%Y%m%d-%H%M%S)"
terraform plan $REPLACE_FLAGS -out="$PLAN_FILE"

echo ""
read -p "Proceed with replacement? (yes/no): " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
    echo ""
    echo "⚡ Applying replacement..."
    terraform apply "$PLAN_FILE"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Replacement successful!"
        rm -f "$PLAN_FILE"
    else
        echo ""
        echo "❌ Replacement failed!"
        echo "Plan file saved: $PLAN_FILE"
        exit 1
    fi
else
    echo "❌ Replacement cancelled"
    rm -f "$PLAN_FILE"
fi
