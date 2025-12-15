#!/bin/bash
echo "🔍 Checking for downtime risks..."
echo ""

# Run plan and capture output
terraform plan -no-color > /tmp/tfplan.txt 2>&1

# Check for dangerous operations
echo "❌ Resources to be DESTROYED:"
grep -E "^  # .* will be destroyed" /tmp/tfplan.txt || echo "  None - SAFE ✅"
echo ""

echo "⚠️  Resources to be REPLACED (destroy + create):"
grep -E "^  # .* must be replaced" /tmp/tfplan.txt || echo "  None - SAFE ✅"
echo ""

echo "➕ Resources to be CREATED:"
grep -E "^  # .* will be created" /tmp/tfplan.txt || echo "  None"
echo ""

echo "📊 Summary:"
grep "Plan:" /tmp/tfplan.txt

echo ""
echo "✅ If you see '0 to destroy' and '0 to replace', you're safe!":