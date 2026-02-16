# CI/CD Setup Guide

Complete guide to setting up GitHub Actions CI/CD for the iQQ Platform.

## Prerequisites

- GitHub account with admin access to all repositories
- AWS account with appropriate permissions
- GitHub CLI installed (`gh`)
- AWS CLI configured

## Quick Start

### 1. Create S3 Bucket for SAM Deployments

```bash
# Create bucket for SAM artifacts
aws s3 mb s3://iqq-sam-deployments-${AWS_ACCOUNT_ID} --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket iqq-sam-deployments-${AWS_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled
```

### 2. Create IAM User for GitHub Actions

```bash
# Create IAM user
aws iam create-user --user-name github-actions-iqq

# Attach policies (adjust as needed)
aws iam attach-user-policy \
  --user-name github-actions-iqq \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Create access key
aws iam create-access-key --user-name github-actions-iqq
```

Save the Access Key ID and Secret Access Key - you'll need them for GitHub Secrets.

### 3. Configure GitHub Secrets

#### Option A: Automated Setup (Recommended)

```bash
# Run the setup script
./scripts/setup-github-secrets.sh
```

The script will prompt you for:
- AWS Access Key ID
- AWS Secret Access Key
- SAM Deployment S3 Bucket name
- Codecov Token (optional)

#### Option B: Manual Setup

For each repository, go to Settings > Secrets and variables > Actions:

1. Click "New repository secret"
2. Add these secrets:
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
   - `SAM_DEPLOYMENT_BUCKET` - S3 bucket name (e.g., `iqq-sam-deployments-123456789`)
   - `CODECOV_TOKEN` - (Optional) Codecov token for coverage reports

Repeat for all 6 repositories:
- iqq-infrastructure
- iqq-providers
- iqq-lender-service
- iqq-package-service
- iqq-product-service
- iqq-document-service

### 4. Configure Environment Protection Rules

For each repository:

1. Go to Settings > Environments
2. Create two environments:

#### Development Environment

- **Name:** `development`
- **Deployment branches:** `develop` only
- **Protection rules:**
  - Required reviewers: 0 (optional)
  - Wait timer: 0 minutes

#### Production Environment

- **Name:** `production`
- **Deployment branches:** `main` only
- **Protection rules:**
  - Required reviewers: 1+ (recommended)
  - Wait timer: 5 minutes (recommended)
  - Prevent self-review: Yes (recommended)

### 5. Set Up Branch Protection

For each repository, configure branch protection rules:

#### Main Branch

Settings > Branches > Add rule:

- **Branch name pattern:** `main`
- **Protect matching branches:**
  - ✅ Require a pull request before merging
  - ✅ Require approvals: 1
  - ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging
  - ✅ Include administrators

#### Develop Branch

Settings > Branches > Add rule:

- **Branch name pattern:** `develop`
- **Protect matching branches:**
  - ✅ Require a pull request before merging
  - ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging

### 6. Configure Terraform Backend (Infrastructure Only)

Update `iqq-infrastructure/main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "iqq-terraform-state-${AWS_ACCOUNT_ID}"
    key            = "iqq-infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Create the backend resources:

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://iqq-terraform-state-${AWS_ACCOUNT_ID} --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket iqq-terraform-state-${AWS_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket iqq-terraform-state-${AWS_ACCOUNT_ID} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Testing the Setup

### 1. Test SAM Service Deployment

```bash
# Create a test branch
cd iqq-lender-service
git checkout -b test-cicd
git push origin test-cicd

# Create PR to develop
gh pr create --base develop --title "Test CI/CD" --body "Testing GitHub Actions"

# Watch the workflow
gh run watch
```

### 2. Test Terraform Deployment

```bash
# Create a test branch
cd iqq-infrastructure
git checkout -b test-terraform
git push origin test-terraform

# Create PR to develop
gh pr create --base develop --title "Test Terraform CI/CD" --body "Testing Terraform workflow"

# Watch the workflow
gh run watch
```

## Deployment Workflow

### Development Deployment

```bash
# 1. Create feature branch
git checkout develop
git pull origin develop
git checkout -b feature/my-feature

# 2. Make changes and commit
git add .
git commit -m "Add new feature"
git push origin feature/my-feature

# 3. Create PR to develop
gh pr create --base develop --title "Add new feature" --body "Description"

# 4. Wait for CI checks to pass
gh pr checks

# 5. Merge PR (or use GitHub UI)
gh pr merge --squash

# 6. Automatic deployment to development
# Watch deployment
gh run watch
```

### Production Deployment

```bash
# 1. Create PR from develop to main
git checkout develop
git pull origin develop
gh pr create --base main --title "Release v1.0.0" --body "Production release"

# 2. Review Terraform plan (if infrastructure changes)
# Check the PR comments for the plan

# 3. Merge PR (requires approval)
gh pr merge --squash

# 4. Approve deployment (if environment protection enabled)
# Go to Actions tab > Select workflow run > Review deployments

# 5. Monitor deployment
gh run watch
```

## Monitoring Deployments

### GitHub Actions UI

```bash
# List recent workflow runs
gh run list

# Watch a specific run
gh run watch <run-id>

# View run logs
gh run view <run-id> --log
```

### AWS Console

1. **CloudFormation Stacks:**
   - https://console.aws.amazon.com/cloudformation
   - Check stack status and events

2. **Lambda Functions:**
   - https://console.aws.amazon.com/lambda
   - Verify function updates

3. **CloudWatch Logs:**
   - https://console.aws.amazon.com/cloudwatch
   - Monitor deployment logs

## Troubleshooting

### Workflow Fails on Test Job

**Check:**
1. Tests pass locally: `npm test`
2. Dependencies installed: `npm ci`
3. Node version matches: `node --version` (should be 20.x)

**Fix:**
```bash
# Update package-lock.json
npm install
git add package-lock.json
git commit -m "Update dependencies"
```

### Workflow Fails on Deploy Job

**Check:**
1. AWS credentials are valid
2. S3 bucket exists and is accessible
3. IAM permissions are sufficient

**Fix:**
```bash
# Test AWS credentials
aws sts get-caller-identity

# Test S3 bucket access
aws s3 ls s3://iqq-sam-deployments-${AWS_ACCOUNT_ID}

# Test SAM deployment locally
sam deploy --guided
```

### Terraform Plan Fails

**Check:**
1. Backend is configured correctly
2. State bucket exists
3. DynamoDB table exists (for locking)

**Fix:**
```bash
# Initialize backend
terraform init

# Test plan locally
terraform plan
```

### Environment Protection Blocks Deployment

**Check:**
1. Environment is configured in repository settings
2. Required reviewers are available
3. Deployment branch matches environment rules

**Fix:**
1. Go to repository Settings > Environments
2. Review protection rules
3. Approve deployment in Actions tab

## Best Practices

### 1. Always Use Pull Requests

- Never push directly to `main` or `develop`
- Create feature branches for all changes
- Wait for CI checks before merging

### 2. Review Terraform Plans

- Always review plans in PR comments
- Check for unexpected resource changes
- Verify costs before applying

### 3. Test Locally First

```bash
# SAM services
npm test
sam build
sam validate

# Terraform
terraform fmt
terraform validate
terraform plan
```

### 4. Use Semantic Versioning

Tag releases with semantic versions:

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### 5. Monitor Deployments

- Watch CloudWatch Logs during deployment
- Check Lambda metrics after deployment
- Verify API endpoints are responding

### 6. Rollback Strategy

If deployment fails:

```bash
# SAM services - revert to previous version
git revert <commit-hash>
git push origin main

# Terraform - revert infrastructure changes
git revert <commit-hash>
git push origin main
```

## Security Considerations

### IAM Permissions

Use least privilege principle:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "lambda:*",
        "apigateway:*",
        "s3:*",
        "iam:PassRole",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Secrets Rotation

Rotate AWS credentials regularly:

```bash
# Create new access key
aws iam create-access-key --user-name github-actions-iqq

# Update GitHub secrets
gh secret set AWS_ACCESS_KEY_ID --repo <repo>
gh secret set AWS_SECRET_ACCESS_KEY --repo <repo>

# Delete old access key
aws iam delete-access-key --user-name github-actions-iqq --access-key-id <old-key-id>
```

### Audit Logs

Enable CloudTrail for audit logging:

```bash
aws cloudtrail create-trail \
  --name iqq-audit-trail \
  --s3-bucket-name iqq-audit-logs-${AWS_ACCOUNT_ID}

aws cloudtrail start-logging --name iqq-audit-trail
```

## Cost Optimization

### GitHub Actions Minutes

- **Free tier:** 2,000 minutes/month (private repos)
- **Public repos:** Unlimited
- **Optimization:**
  - Use caching for dependencies
  - Skip unnecessary jobs
  - Use self-hosted runners for heavy workloads

### AWS Resources

- Use `--no-fail-on-empty-changeset` to avoid unnecessary deployments
- Clean up old CloudFormation stacks
- Delete unused S3 artifacts after 30 days

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [GitHub CLI Documentation](https://cli.github.com/manual/)

---

**Last Updated:** February 16, 2026  
**Version:** 1.0.0
