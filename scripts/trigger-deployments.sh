#!/bin/bash

# Script to trigger version deployments via GitHub CLI
# Requires: gh CLI installed and authenticated
# Usage: ./scripts/trigger-deployments.sh

set -e

echo "🚀 API Version Deployment Trigger"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo ""
    echo "Please install it:"
    echo "  macOS: brew install gh"
    echo "  Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    echo ""
    echo "Or trigger workflows manually via GitHub web interface:"
    echo "  https://github.com/rgcleanslage/iqq-project/actions/workflows/deploy-version.yml"
    echo ""
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo ""
    echo "Please authenticate:"
    echo "  gh auth login"
    echo ""
    exit 1
fi

echo "✅ GitHub CLI is installed and authenticated"
echo ""

# Function to trigger deployment
trigger_deployment() {
    local version=$1
    local services=$2
    local environment=$3
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Triggering Deployment: $version"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Version: $version"
    echo "Services: $services"
    echo "Environment: $environment"
    echo ""
    
    # Trigger workflow
    gh workflow run deploy-version.yml \
        --repo rgcleanslage/iqq-project \
        --ref main \
        -f version="$version" \
        -f services="$services" \
        -f environment="$environment"
    
    if [ $? -eq 0 ]; then
        echo "✅ Deployment triggered successfully"
        echo ""
        echo "Monitor progress:"
        echo "  https://github.com/rgcleanslage/iqq-project/actions"
        echo ""
    else
        echo "❌ Failed to trigger deployment"
        exit 1
    fi
}

# Ask user which version to deploy
echo "Which version would you like to deploy?"
echo "  1) v1 only"
echo "  2) v2 only"
echo "  3) Both v1 and v2 (sequential)"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        trigger_deployment "v1" "all" "dev"
        ;;
    2)
        trigger_deployment "v2" "all" "dev"
        ;;
    3)
        echo "Deploying both versions sequentially..."
        echo ""
        trigger_deployment "v1" "all" "dev"
        echo "⏳ Waiting 5 seconds before triggering v2..."
        sleep 5
        trigger_deployment "v2" "all" "dev"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Deployment(s) Triggered"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo "   1. Monitor workflow progress in GitHub Actions"
echo "   2. Wait for completion (~30-40 minutes)"
echo "   3. Verify deployments with verification script"
echo ""
echo "🔗 Links:"
echo "   Actions: https://github.com/rgcleanslage/iqq-project/actions"
echo "   Workflow: https://github.com/rgcleanslage/iqq-project/actions/workflows/deploy-version.yml"
echo ""
