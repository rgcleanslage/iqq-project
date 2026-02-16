#!/bin/bash

# Setup GitHub Actions Secrets
# This script helps configure required secrets for all repositories

set -e

echo "========================================="
echo "GitHub Actions Secrets Setup"
echo "========================================="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
    echo "Error: Not logged in to GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

# Get GitHub username
GITHUB_USER=$(gh api user -q .login)
echo "GitHub User: $GITHUB_USER"
echo ""

# List of repositories
REPOS=(
    "iqq-infrastructure"
    "iqq-providers"
    "iqq-lender-service"
    "iqq-package-service"
    "iqq-product-service"
    "iqq-document-service"
)

# Prompt for AWS credentials
echo "Enter AWS credentials for deployment:"
echo ""
read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""
read -p "SAM Deployment S3 Bucket: " SAM_DEPLOYMENT_BUCKET
echo ""

# Optional: Codecov token
read -p "Codecov Token (optional, press Enter to skip): " CODECOV_TOKEN
echo ""

# Confirm before proceeding
echo "========================================="
echo "Ready to set secrets for repositories:"
for repo in "${REPOS[@]}"; do
    echo "  - $GITHUB_USER/$repo"
done
echo ""
echo "Secrets to be set:"
echo "  - AWS_ACCESS_KEY_ID"
echo "  - AWS_SECRET_ACCESS_KEY"
echo "  - SAM_DEPLOYMENT_BUCKET"
if [ -n "$CODECOV_TOKEN" ]; then
    echo "  - CODECOV_TOKEN"
fi
echo "========================================="
echo ""
read -p "Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Setting secrets..."
echo ""

# Set secrets for each repository
for repo in "${REPOS[@]}"; do
    echo "Processing $repo..."
    
    # Set AWS Access Key ID
    echo "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID \
        --repo "$GITHUB_USER/$repo" \
        --body -
    
    # Set AWS Secret Access Key
    echo "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY \
        --repo "$GITHUB_USER/$repo" \
        --body -
    
    # Set SAM Deployment Bucket
    echo "$SAM_DEPLOYMENT_BUCKET" | gh secret set SAM_DEPLOYMENT_BUCKET \
        --repo "$GITHUB_USER/$repo" \
        --body -
    
    # Set Codecov Token if provided
    if [ -n "$CODECOV_TOKEN" ]; then
        echo "$CODECOV_TOKEN" | gh secret set CODECOV_TOKEN \
            --repo "$GITHUB_USER/$repo" \
            --body -
    fi
    
    echo "  ✓ Secrets set for $repo"
done

echo ""
echo "========================================="
echo "✓ All secrets configured successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Create S3 bucket for SAM deployments (if not exists):"
echo "   aws s3 mb s3://$SAM_DEPLOYMENT_BUCKET --region us-east-1"
echo ""
echo "2. Configure environment protection rules in GitHub:"
echo "   - Go to each repository > Settings > Environments"
echo "   - Create 'development' and 'production' environments"
echo "   - Add protection rules (reviewers, wait time, etc.)"
echo ""
echo "3. Push code to trigger workflows:"
echo "   git push origin develop  # Deploy to development"
echo "   git push origin main     # Deploy to production"
echo ""
