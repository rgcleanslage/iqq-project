# GitHub OIDC Setup Guide

This guide explains how to set up OpenID Connect (OIDC) trust between GitHub Actions and AWS, eliminating the need for long-lived AWS access keys.

## Benefits of OIDC

✅ **No Long-Lived Credentials** - No AWS access keys stored in GitHub  
✅ **Automatic Rotation** - Temporary credentials expire automatically  
✅ **Fine-Grained Access** - Different roles for different repositories  
✅ **Audit Trail** - CloudTrail logs show which GitHub workflow assumed which role  
✅ **Security Best Practice** - Recommended by both GitHub and AWS  

## Architecture

```
┌─────────────────┐
│ GitHub Actions  │
│   Workflow      │
└────────┬────────┘
         │ 1. Request token
         ▼
┌─────────────────┐
│ GitHub OIDC     │
│   Provider      │
└────────┬────────┘
         │ 2. Issue JWT token
         ▼
┌─────────────────┐
│ AWS STS         │
│ AssumeRoleWith  │
│ WebIdentity     │
└────────┬────────┘
         │ 3. Return temporary credentials
         ▼
┌─────────────────┐
│ AWS IAM Role    │
│ (SAM/Terraform) │
└─────────────────┘
```

## Prerequisites

- AWS CLI configured with admin access
- Terraform installed
- GitHub repositories created
- AWS account ID

## Step 1: Deploy OIDC Infrastructure

The OIDC provider and IAM roles are managed by Terraform in the `iqq-infrastructure` repository.

### 1.1 Update GitHub Repository List

Edit `iqq-infrastructure/variables.tf` and update the `github_repositories` variable with your GitHub username:

```hcl
variable "github_repositories" {
  description = "List of GitHub repository patterns allowed to assume AWS roles"
  type        = list(string)
  default = [
    "repo:YOUR_GITHUB_USERNAME/iqq-infrastructure:*",
    "repo:YOUR_GITHUB_USERNAME/iqq-providers:*",
    "repo:YOUR_GITHUB_USERNAME/iqq-lender-service:*",
    "repo:YOUR_GITHUB_USERNAME/iqq-package-service:*",
    "repo:YOUR_GITHUB_USERNAME/iqq-product-service:*",
    "repo:YOUR_GITHUB_USERNAME/iqq-document-service:*"
  ]
}
```

### 1.2 Deploy the Infrastructure

```bash
cd iqq-infrastructure

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var="environment=dev"

# Apply the changes
terraform apply -var="environment=dev"
```

### 1.3 Get the Role ARNs

After deployment, get the role ARNs:

```bash
# Get SAM deployment role ARN
terraform output -raw github_sam_role_arn

# Get Terraform deployment role ARN
terraform output -raw github_terraform_role_arn
```

Save these ARNs - you'll need them for GitHub secrets.

## Step 2: Configure GitHub Secrets

For each repository, you need to set the `AWS_ROLE_ARN` secret.

### Option A: Using GitHub CLI (Recommended)

```bash
# Get the role ARN from Terraform
SAM_ROLE_ARN=$(cd iqq-infrastructure && terraform output -raw github_sam_role_arn)
TERRAFORM_ROLE_ARN=$(cd iqq-infrastructure && terraform output -raw github_terraform_role_arn)

# Set secret for SAM repositories
for repo in iqq-providers iqq-lender-service iqq-package-service iqq-product-service iqq-document-service; do
  echo "$SAM_ROLE_ARN" | gh secret set AWS_ROLE_ARN --repo YOUR_GITHUB_USERNAME/$repo
done

# Set secret for Terraform repository
echo "$TERRAFORM_ROLE_ARN" | gh secret set AWS_ROLE_ARN --repo YOUR_GITHUB_USERNAME/iqq-infrastructure
```

### Option B: Manual Setup

For each repository:

1. Go to repository Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Name: `AWS_ROLE_ARN`
4. Value: The role ARN from Terraform output
   - For SAM repos: Use `github_sam_role_arn`
   - For infrastructure repo: Use `github_terraform_role_arn`

### Required Secrets Per Repository

| Repository | Secret Name | Value |
|------------|-------------|-------|
| iqq-providers | `AWS_ROLE_ARN` | SAM role ARN |
| iqq-lender-service | `AWS_ROLE_ARN` | SAM role ARN |
| iqq-package-service | `AWS_ROLE_ARN` | SAM role ARN |
| iqq-product-service | `AWS_ROLE_ARN` | SAM role ARN |
| iqq-document-service | `AWS_ROLE_ARN` | SAM role ARN |
| iqq-infrastructure | `AWS_ROLE_ARN` | Terraform role ARN |
| All repos | `SAM_DEPLOYMENT_BUCKET` | S3 bucket name |

## Step 3: Update Workflows (Already Done)

The workflows have been updated to use OIDC. Key changes:

### Before (Access Keys):
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

### After (OIDC):
```yaml
permissions:
  id-token: write
  contents: read

- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
```

## Step 4: Test the Setup

### 4.1 Test SAM Deployment

```bash
cd iqq-lender-service

# Create a test branch
git checkout -b test-oidc
git push origin test-oidc

# Create PR to develop
gh pr create --base develop --title "Test OIDC" --body "Testing OIDC authentication"

# Watch the workflow
gh run watch
```

### 4.2 Test Terraform Deployment

```bash
cd iqq-infrastructure

# Create a test branch
git checkout -b test-oidc
git push origin test-oidc

# Create PR to develop
gh pr create --base develop --title "Test OIDC" --body "Testing OIDC authentication"

# Watch the workflow
gh run watch
```

## Step 5: Remove Old Access Keys (Optional)

Once OIDC is working, you can remove the old access keys:

### 5.1 Remove GitHub Secrets

```bash
# Remove old secrets from all repositories
for repo in iqq-infrastructure iqq-providers iqq-lender-service iqq-package-service iqq-product-service iqq-document-service; do
  gh secret remove AWS_ACCESS_KEY_ID --repo YOUR_GITHUB_USERNAME/$repo
  gh secret remove AWS_SECRET_ACCESS_KEY --repo YOUR_GITHUB_USERNAME/$repo
done
```

### 5.2 Delete IAM User

```bash
# List access keys for the user
aws iam list-access-keys --user-name github-actions-iqq

# Delete access keys
aws iam delete-access-key --user-name github-actions-iqq --access-key-id <KEY_ID>

# Detach policies
aws iam list-attached-user-policies --user-name github-actions-iqq
aws iam detach-user-policy --user-name github-actions-iqq --policy-arn <POLICY_ARN>

# Delete user
aws iam delete-user --user-name github-actions-iqq
```

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause:** The GitHub repository pattern doesn't match the IAM role trust policy.

**Solution:** Check the repository pattern in the trust policy:

```bash
aws iam get-role --role-name github-actions-sam-dev --query 'Role.AssumeRolePolicyDocument'
```

Ensure it matches your repository format: `repo:owner/repo:*`

### Error: "No OIDC provider found"

**Cause:** The OIDC provider wasn't created or was deleted.

**Solution:** Redeploy the Terraform infrastructure:

```bash
cd iqq-infrastructure
terraform apply -var="environment=dev"
```

### Error: "Access Denied" during deployment

**Cause:** The IAM role doesn't have sufficient permissions.

**Solution:** Review and update the IAM policy in `modules/github-oidc/main.tf`

### Workflow fails with "Unable to assume role"

**Cause:** Missing `id-token: write` permission in workflow.

**Solution:** Ensure the workflow has:

```yaml
permissions:
  id-token: write
  contents: read
```

## Security Best Practices

### 1. Restrict by Branch

Limit role assumption to specific branches:

```hcl
variable "github_repositories" {
  default = [
    "repo:owner/repo:ref:refs/heads/main",
    "repo:owner/repo:ref:refs/heads/develop"
  ]
}
```

### 2. Restrict by Environment

Use different roles for different environments:

```hcl
# Production role - only main branch
"repo:owner/repo:ref:refs/heads/main"

# Development role - develop branch
"repo:owner/repo:ref:refs/heads/develop"
```

### 3. Least Privilege

Grant only the permissions needed:

```hcl
# Instead of PowerUserAccess, use specific permissions
actions = [
  "lambda:UpdateFunctionCode",
  "lambda:UpdateFunctionConfiguration"
]
```

### 4. Monitor Usage

Enable CloudTrail logging:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=github-actions-sam-dev \
  --max-results 50
```

## Advanced Configuration

### Multiple Environments

Create separate roles for each environment:

```hcl
# In variables.tf
variable "github_repositories_prod" {
  default = ["repo:owner/repo:ref:refs/heads/main"]
}

variable "github_repositories_dev" {
  default = ["repo:owner/repo:ref:refs/heads/develop"]
}
```

### Custom Session Duration

Increase session duration for long-running deployments:

```hcl
resource "aws_iam_role" "github_actions_sam" {
  max_session_duration = 7200  # 2 hours
}
```

### Conditional Deployments

Use GitHub environments with protection rules:

```yaml
environment:
  name: production
  url: https://api.example.com
```

## Cost Considerations

OIDC authentication is **free**:
- No cost for OIDC provider
- No cost for STS AssumeRoleWithWebIdentity calls
- Standard IAM role costs (free)

Compared to access keys:
- ✅ No risk of leaked credentials
- ✅ No need for credential rotation
- ✅ Better audit trail

## Additional Resources

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)

---

**Last Updated:** February 16, 2026  
**Version:** 1.0.0
