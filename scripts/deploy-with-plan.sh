#!/bin/bash
# Safe Terraform deployment using plan files
# Usage: ./deploy-with-plan.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PLAN_FILE="tfplan-${TIMESTAMP}"
PLAN_JSON="plan-${TIMESTAMP}.json"
PLAN_TEXT="plan-${TIMESTAMP}.txt"

echo "🚀 Terraform Deployment Script"
echo "================================"
echo "Environment: $ENVIRONMENT"
echo "Timestamp: $TIMESTAMP"
echo ""

# Step 1: Format check
echo "📝 Step 1: Checking format..."
if ! terraform fmt -check -recursive; then
    echo "⚠️  Format issues found. Auto-fixing..."
    terraform fmt -recursive
fi
echo "✅ Format check passed"
echo ""

# Step 2: Validation
echo "🔍 Step 2: Validating configuration..."
terraform validate
echo "✅ Validation passed"
echo ""

# Step 3: Generate plan
echo "📋 Step 3: Generating plan..."
terraform plan \
    -out="${PLAN_FILE}" \
    -var="environment=${ENVIRONMENT}" \
    -detailed-exitcode || PLAN_EXIT_CODE=$?

# Check exit code
if [ "${PLAN_EXIT_CODE}" = "0" ]; then
    echo "✅ No changes detected"
    exit 0
elif [ "${PLAN_EXIT_CODE}" = "1" ]; then
    echo "❌ Error during planning"
    exit 1
fi

echo "✅ Plan generated: ${PLAN_FILE}"
echo ""

# Step 4: Export plan in multiple formats
echo "📤 Step 4: Exporting plan..."
terraform show "${PLAN_FILE}" > "${PLAN_TEXT}"
terraform show -json "${PLAN_FILE}" > "${PLAN_JSON}"
echo "✅ Plan exported:"
echo "   - Text: ${PLAN_TEXT}"
echo "   - JSON: ${PLAN_JSON}"
echo ""

# Step 5: Show summary
echo "📊 Step 5: Plan Summary"
echo "======================="
terraform show "${PLAN_FILE}" | grep -E "Plan:|^  # |will be created|will be updated|will be destroyed" | head -20
echo ""

# Step 6: Cost estimation (optional - requires infracost)
if command -v infracost &> /dev/null; then
    echo "💰 Step 6: Cost Estimation..."
    infracost breakdown --path "${PLAN_JSON}" --format table || echo "⚠️  Cost estimation unavailable"
    echo ""
fi

# Step 7: Ask for confirmation
echo "🤔 Review the plan above carefully."
echo ""
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Deployment cancelled"
    echo "Plan files saved for review:"
    echo "   - ${PLAN_FILE}"
    echo "   - ${PLAN_TEXT}"
    echo "   - ${PLAN_JSON}"
    exit 0
fi

# Step 8: Apply the plan
echo ""
echo "⚡ Step 8: Applying plan..."
terraform apply "${PLAN_FILE}"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    
    # Archive plan files
    mkdir -p plans/archive
    mv "${PLAN_FILE}" "plans/archive/"
    mv "${PLAN_TEXT}" "plans/archive/"
    mv "${PLAN_JSON}" "plans/archive/"
    
    echo "📁 Plan files archived to: plans/archive/"
    
    # Tag deployment
    if [ -d .git ]; then
        git tag -a "deploy-${TIMESTAMP}" -m "Deployed to ${ENVIRONMENT} by $(whoami)" || true
        echo "🏷️  Git tag created: deploy-${TIMESTAMP}"
    fi
else
    echo ""
    echo "❌ Deployment failed!"
    exit 1
fi
