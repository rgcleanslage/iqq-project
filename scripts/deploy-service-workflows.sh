#!/bin/bash

# Script to deploy service deployment workflows to all service repositories
# Usage: ./scripts/deploy-service-workflows.sh

set -e

echo "🚀 Deploying service deployment workflows"
echo ""

# Define services
SERVICES=(
  "package"
  "lender"
  "product"
  "document"
)

# Track success/failure
SUCCESS_COUNT=0
FAILED_REPOS=()

# Function to deploy workflow to a service
deploy_workflow() {
  local service=$1
  local repo="iqq-${service}-service"
  
  echo "📦 Processing: $repo"
  
  # Check if directory exists
  if [ ! -d "$repo" ]; then
    echo "   ⚠️  Directory not found: $repo (skipping)"
    FAILED_REPOS+=("$repo (not found)")
    return 1
  fi
  
  cd "$repo"
  
  # Create .github/workflows directory if it doesn't exist
  mkdir -p .github/workflows
  
  # Copy and customize workflow template
  echo "   📝 Creating deploy.yml workflow..."
  sed "s/{SERVICE_NAME}/${service}/g" ../scripts/service-deploy-workflow.yml > .github/workflows/deploy.yml
  
  # Check if on main branch
  CURRENT_BRANCH=$(git branch --show-current)
  if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "   ⚠️  Not on main branch (currently on $CURRENT_BRANCH), switching..."
    git checkout main
  fi
  
  # Add and commit
  git add .github/workflows/deploy.yml
  
  if git diff --cached --quiet; then
    echo "   ℹ️  No changes to commit (workflow already exists)"
  else
    git commit -m "feat: add service deployment workflow

- Add GitHub Actions workflow for version-based deployment
- Support v1 and v2 version deployment
- Includes build, test, deploy, and alias update steps
- Automated by deploy-service-workflows.sh script"
    
    echo "   📤 Pushing to remote..."
    git push origin main
    
    echo "   ✅ Workflow deployed to $repo"
  fi
  
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  
  cd ..
  echo ""
}

# Deploy workflows to all services
for service in "${SERVICES[@]}"; do
  deploy_workflow "$service"
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "   ✅ Successfully processed: $SUCCESS_COUNT services"

if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
  echo "   ❌ Failed/Skipped: ${#FAILED_REPOS[@]} services"
  for repo in "${FAILED_REPOS[@]}"; do
    echo "      - $repo"
  done
fi

echo ""
echo "🎉 Service workflow deployment complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Verify workflows in each service repository"
echo "   2. Use 'Deploy API Version' workflow to deploy services"
echo "   3. Or manually trigger deploy.yml in each service"
echo ""
