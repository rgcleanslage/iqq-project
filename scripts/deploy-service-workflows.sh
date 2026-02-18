#!/bin/bash

# Script to deploy service deployment workflows to all service repositories
# This copies the template workflow to each service repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/service-deploy-workflow.yml"

# Services to update
SERVICES=("package" "lender" "product" "document")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Deploying Service Workflows"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Template file not found: $TEMPLATE_FILE"
    exit 1
fi

echo "✅ Template file found: $TEMPLATE_FILE"
echo ""

for SERVICE in "${SERVICES[@]}"; do
    SERVICE_DIR="$ROOT_DIR/../iqq-${SERVICE}-service"
    WORKFLOW_DIR="$SERVICE_DIR/.github/workflows"
    WORKFLOW_FILE="$WORKFLOW_DIR/deploy.yml"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Processing: iqq-${SERVICE}-service"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if service directory exists
    if [ ! -d "$SERVICE_DIR" ]; then
        echo "⚠️  Service directory not found: $SERVICE_DIR"
        echo "   Skipping..."
        echo ""
        continue
    fi
    
    echo "✅ Service directory found"
    
    # Create .github/workflows directory if it doesn't exist
    if [ ! -d "$WORKFLOW_DIR" ]; then
        echo "📁 Creating workflow directory..."
        mkdir -p "$WORKFLOW_DIR"
    fi
    
    # Copy and customize template
    echo "📝 Creating deployment workflow..."
    sed "s/{SERVICE_NAME}/${SERVICE}/g" "$TEMPLATE_FILE" > "$WORKFLOW_FILE"
    
    echo "✅ Workflow created: $WORKFLOW_FILE"
    
    # Check if we're in a git repository
    if [ -d "$SERVICE_DIR/.git" ]; then
        cd "$SERVICE_DIR"
        
        # Check if there are changes
        if git diff --quiet .github/workflows/deploy.yml 2>/dev/null; then
            echo "ℹ️  No changes to commit"
        else
            echo "📤 Committing workflow..."
            git add .github/workflows/deploy.yml
            git commit -m "ci: add version deployment workflow

- Add workflow_dispatch deployment workflow
- Support v1 and v2 version deployments
- Integrate with centralized orchestration
- Auto-update Lambda aliases"
            
            echo "✅ Changes committed"
            echo ""
            echo "📌 To push changes, run:"
            echo "   cd $SERVICE_DIR && git push origin main"
        fi
        
        cd "$ROOT_DIR"
    else
        echo "⚠️  Not a git repository, skipping commit"
    fi
    
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Workflow Deployment Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   - Template: $TEMPLATE_FILE"
echo "   - Services: ${SERVICES[*]}"
echo ""
echo "📌 Next Steps:"
echo "   1. Review the generated workflows in each service repository"
echo "   2. Push changes to each service repository"
echo "   3. Ensure GitHub secrets are configured:"
echo "      - AWS_ROLE_ARN"
echo "      - SAM_DEPLOYMENT_BUCKET"
echo "   4. Test workflows with manual dispatch"
echo ""
echo "🚀 To push all changes at once:"
echo "   for service in ${SERVICES[*]}; do"
echo "     cd ../iqq-\${service}-service && git push origin main"
echo "   done"
echo ""
