#!/bin/bash

# Script to check deployment status
# Usage: ./scripts/check-deployment-status.sh

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Deployment Status Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check GitHub Actions workflows
echo "🔄 GitHub Actions Workflows:"
echo ""
gh run list --workflow="deploy-version.yml" --repo rgcleanslage/iqq-project --limit 5
echo ""

# Check if gh CLI is available and AWS CLI
if ! command -v aws &> /dev/null; then
    echo "⚠️  AWS CLI not installed - skipping Lambda alias check"
    echo ""
    exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Lambda Alias Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SERVICES=("package" "lender" "product" "document")

for service in "${SERVICES[@]}"; do
    FUNCTION_NAME="iqq-${service}-service-dev"
    echo "📦 $FUNCTION_NAME:"
    
    # Check if function exists
    if aws lambda get-function --function-name "$FUNCTION_NAME" --region us-east-1 &> /dev/null; then
        # List aliases
        ALIASES=$(aws lambda list-aliases \
            --function-name "$FUNCTION_NAME" \
            --region us-east-1 \
            --query 'Aliases[*].[Name,FunctionVersion]' \
            --output text 2>/dev/null)
        
        if [ -n "$ALIASES" ]; then
            echo "$ALIASES" | while read -r name version; do
                echo "   ✅ Alias: $name -> Version: $version"
            done
        else
            echo "   ⚠️  No aliases found"
        fi
    else
        echo "   ⚠️  Function not found"
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To view detailed workflow logs:"
echo "  gh run view <run-id> --repo rgcleanslage/iqq-project"
echo ""
echo "To watch workflow progress:"
echo "  gh run watch <run-id> --repo rgcleanslage/iqq-project"
echo ""
echo "Web interface:"
echo "  https://github.com/rgcleanslage/iqq-project/actions"
echo ""
