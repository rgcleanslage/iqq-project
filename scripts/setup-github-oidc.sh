#!/bin/bash

# Setup GitHub OIDC Trust with AWS
# This script automates the OIDC setup process

set -e

echo "========================================="
echo "GitHub OIDC Setup for AWS"
echo "========================================="
echo ""

# Check prerequisites
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed"
    echo "Install it from: https://www.terraform.io/downloads"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo "Error: Not logged in to GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

# Get GitHub username
GITHUB_USER=$(gh api user -q .login)
echo "GitHub User: $GITHUB_USER"
echo ""

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Prompt for environment
read -p "Environment (dev/staging/prod) [dev]: " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}
echo ""

# Confirm before proceeding
echo "========================================="
echo "This script will:"
echo "1. Deploy OIDC provider and IAM roles via Terraform"
echo "2. Configure GitHub secrets for all repositories"
echo "3. Test the OIDC authentication"
echo "========================================="
echo ""
read -p "Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Deploying OIDC infrastructure..."
echo ""

# Navigate to infrastructure directory
cd iqq-infrastructure

# Initialize Terraform
terraform init

# Apply Terraform
terraform apply -var="environment=$ENVIRONMENT" -auto-approve

# Get role ARNs
SAM_ROLE_ARN=$(terraform output -raw github_sam_role_arn)
TERRAFORM_ROLE_ARN=$(terraform output -raw github_terraform_role_arn)

echo ""
echo "✓ OIDC infrastructure deployed"
echo "  SAM Role ARN: $SAM_ROLE_ARN"
echo "  Terraform Role ARN: $TERRAFORM_ROLE_ARN"
echo ""

# Navigate back to root
cd ..

echo "Step 2: Configuring GitHub secrets..."
echo ""

# List of SAM repositories
SAM_REPOS=(
    "iqq-providers"
    "iqq-lender-service"
    "iqq-package-service"
    "iqq-product-service"
    "iqq-document-service"
)

# Set secrets for SAM repositories
for repo in "${SAM_REPOS[@]}"; do
    echo "  Setting secrets for $repo..."
    echo "$SAM_ROLE_ARN" | gh secret set AWS_ROLE_ARN --repo "$GITHUB_USER/$repo"
done

# Set secret for Terraform repository
echo "  Setting secrets for iqq-infrastructure..."
echo "$TERRAFORM_ROLE_ARN" | gh secret set AWS_ROLE_ARN --repo "$GITHUB_USER/iqq-infrastructure"

echo ""
echo "✓ GitHub secrets configured"
echo ""

# Prompt for S3 bucket
read -p "SAM Deployment S3 Bucket name: " SAM_BUCKET
echo ""

if [ -n "$SAM_BUCKET" ]; then
    echo "Setting SAM_DEPLOYMENT_BUCKET secret..."
    for repo in "${SAM_REPOS[@]}" "iqq-infrastructure"; do
        echo "$SAM_BUCKET" | gh secret set SAM_DEPLOYMENT_BUCKET --repo "$GITHUB_USER/$repo"
    done
    echo "✓ SAM_DEPLOYMENT_BUCKET secret set"
    echo ""
fi

echo "========================================="
echo "✓ OIDC Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Test the setup by pushing to a repository:"
echo "   cd iqq-lender-service"
echo "   git checkout -b test-oidc"
echo "   git push origin test-oidc"
echo "   gh pr create --base develop --title 'Test OIDC'"
echo ""
echo "2. Watch the workflow:"
echo "   gh run watch"
echo ""
echo "3. If successful, remove old access keys:"
echo "   gh secret remove AWS_ACCESS_KEY_ID --repo $GITHUB_USER/iqq-providers"
echo "   gh secret remove AWS_SECRET_ACCESS_KEY --repo $GITHUB_USER/iqq-providers"
echo "   (repeat for all repositories)"
echo ""
echo "4. Delete the IAM user (if you created one):"
echo "   aws iam delete-access-key --user-name github-actions-iqq --access-key-id <KEY_ID>"
echo "   aws iam delete-user --user-name github-actions-iqq"
echo ""
echo "Documentation: docs/deployment/GITHUB_OIDC_SETUP.md"
echo ""
