#!/bin/bash
# Workspace-based deployment for testing changes
# Usage: ./deploy-with-workspace.sh <workspace-name>

set -e

WORKSPACE_NAME=${1}

if [ -z "$WORKSPACE_NAME" ]; then
    echo "Usage: $0 <workspace-name>"
    echo ""
    echo "Examples:"
    echo "  $0 feature-alb        # Test ALB feature"
    echo "  $0 test-scaling       # Test auto-scaling"
    echo "  $0 experiment-cdn     # Experiment with CDN"
    exit 1
fi

echo "🔧 Terraform Workspace Deployment"
echo "=================================="
echo "Workspace: $WORKSPACE_NAME"
echo ""

# List current workspaces
echo "📋 Current workspaces:"
terraform workspace list
echo ""

# Create or select workspace
if terraform workspace list | grep -q "^\s*${WORKSPACE_NAME}\s*$"; then
    echo "✅ Workspace '$WORKSPACE_NAME' exists, selecting..."
    terraform workspace select "$WORKSPACE_NAME"
else
    echo "🆕 Creating new workspace '$WORKSPACE_NAME'..."
    terraform workspace new "$WORKSPACE_NAME"
fi

echo ""
echo "📍 Current workspace: $(terraform workspace show)"
echo ""

# Initialize if needed
if [ ! -d .terraform ]; then
    echo "🔄 Initializing Terraform..."
    terraform init
    echo ""
fi

# Plan changes
echo "📋 Planning changes in workspace '$WORKSPACE_NAME'..."
PLAN_FILE="tfplan-${WORKSPACE_NAME}"
terraform plan -out="$PLAN_FILE"
echo ""

# Show summary
echo "📊 Summary:"
terraform show "$PLAN_FILE" | grep "Plan:" || echo "No changes"
echo ""

# Confirm
read -p "Apply changes to workspace '$WORKSPACE_NAME'? (yes/no): " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
    echo ""
    echo "⚡ Applying changes..."
    terraform apply "$PLAN_FILE"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Deployment to workspace '$WORKSPACE_NAME' successful!"
        echo ""
        echo "💡 Tips:"
        echo "   - Test your changes thoroughly"
        echo "   - When satisfied, switch to production:"
        echo "     terraform workspace select prod"
        echo "     terraform apply"
        echo ""
        echo "   - To delete this workspace (after destroying resources):"
        echo "     terraform destroy"
        echo "     terraform workspace select default"
        echo "     terraform workspace delete $WORKSPACE_NAME"
    fi
else
    echo "❌ Deployment cancelled"
    rm -f "$PLAN_FILE"
fi
