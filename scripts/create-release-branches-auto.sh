#!/bin/bash

# Script to create release branches across all service repositories (non-interactive)
# Usage: ./scripts/create-release-branches-auto.sh <version>
# Example: ./scripts/create-release-branches-auto.sh v1

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "❌ Error: Version argument required"
  echo "Usage: $0 <version>"
  echo "Example: $0 v1"
  exit 1
fi

# Validate version format
if [[ ! "$VERSION" =~ ^v[0-9]+$ ]]; then
  echo "❌ Error: Version must be in format v1, v2, etc."
  exit 1
fi

echo "🚀 Creating release branches for version: $VERSION"
echo ""

# Define service repositories
SERVICES=(
  "iqq-package-service"
  "iqq-lender-service"
  "iqq-product-service"
  "iqq-document-service"
)

# Track success/failure
SUCCESS_COUNT=0
FAILED_REPOS=()

# Function to create branch in a repository
create_branch() {
  local repo=$1
  local branch_name="release/$VERSION"
  
  echo "📦 Processing: $repo"
  
  # Check if directory exists
  if [ ! -d "$repo" ]; then
    echo "   ⚠️  Directory not found: $repo (skipping)"
    FAILED_REPOS+=("$repo (not found)")
    return 1
  fi
  
  cd "$repo"
  
  # Check if it's a git repository
  if [ ! -d ".git" ]; then
    echo "   ⚠️  Not a git repository: $repo (skipping)"
    cd ..
    FAILED_REPOS+=("$repo (not a git repo)")
    return 1
  fi
  
  # Fetch latest changes
  echo "   📥 Fetching latest changes..."
  git fetch origin 2>/dev/null || {
    echo "   ⚠️  Could not fetch from remote"
  }
  
  # Check if branch already exists on remote
  if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
    echo "   ℹ️  Branch $branch_name already exists on remote"
    echo "   📥 Checking out existing remote branch..."
    
    # Delete local branch if it exists
    git branch -D "$branch_name" 2>/dev/null || true
    
    # Checkout from remote
    git checkout -b "$branch_name" "origin/$branch_name" 2>/dev/null || {
      git checkout "$branch_name"
    }
    echo "   ✅ Checked out existing branch $branch_name"
  else
    # Check if branch exists locally
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
      echo "   ℹ️  Branch $branch_name exists locally, deleting and recreating..."
      git branch -D "$branch_name"
    fi
    
    # Create new branch from main
    echo "   🌿 Creating new branch from main..."
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
      echo "   ❌ Could not checkout main/master branch"
      cd ..
      FAILED_REPOS+=("$repo (checkout failed)")
      return 1
    }
    
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || {
      echo "   ⚠️  Could not pull latest changes"
    }
    
    git checkout -b "$branch_name"
    
    # Push to remote
    echo "   📤 Pushing branch to remote..."
    git push -u origin "$branch_name" || {
      echo "   ⚠️  Could not push to remote (you may need to push manually)"
    }
    echo "   ✅ Created and pushed branch $branch_name"
  fi
  
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  
  cd ..
  echo ""
}

# Create branches in all service repositories
for service in "${SERVICES[@]}"; do
  create_branch "$service"
done

# Also create branch in infrastructure repository
echo "🏗️  Processing infrastructure repository..."
create_branch "iqq-infrastructure"

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "   ✅ Successfully processed: $SUCCESS_COUNT repositories"

if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
  echo "   ❌ Failed/Skipped: ${#FAILED_REPOS[@]} repositories"
  for repo in "${FAILED_REPOS[@]}"; do
    echo "      - $repo"
  done
fi

echo ""
echo "🎉 Release branch creation complete for $VERSION!"
echo ""
echo "📝 Next steps:"
echo "   1. Verify branches were created correctly"
echo "   2. Proceed with deployment to $VERSION"
echo ""
