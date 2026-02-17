# Manual Deployment Guide

This guide explains how to manually trigger deployments using GitHub Actions workflows.

## Overview

All deployments are now manual and require explicit approval. This gives you full control over when infrastructure changes are applied.

## Workflow Behavior

### Automatic (No Deployment)
- **Pull Requests**: Automatically run tests and validation
- **Push to any branch**: No automatic deployments

### Manual (Requires Action)
- **Terraform Plan/Apply**: Manually triggered via workflow dispatch
- **SAM Deployments**: Manually triggered via workflow dispatch

## How to Deploy

### Option 1: GitHub Web UI

#### Terraform Deployment

1. Go to the repository: https://github.com/rgcleanslage/iqq-infrastructure
2. Click on **Actions** tab
3. Select **Terraform CI/CD** workflow
4. Click **Run workflow** button (top right)
5. Select options:
   - **Environment**: `dev` or `prod`
   - **Action**: `plan` or `apply`
6. Click **Run workflow**

**Example: Plan Development**
```
Environment: dev
Action: plan
```

**Example: Apply Production**
```
Environment: prod
Action: apply
```

#### SAM Service Deployment

1. Go to the service repository (e.g., https://github.com/rgcleanslage/iqq-lender-service)
2. Click on **Actions** tab
3. Select **CI/CD Pipeline** workflow
4. Click **Run workflow** button
5. Select **Environment**: `dev` or `prod`
6. Click **Run workflow**

### Option 2: GitHub CLI

#### Terraform Deployment

```bash
# Plan development
gh workflow run terraform.yml \
  --repo rgcleanslage/iqq-infrastructure \
  --ref main \
  -f environment=dev \
  -f action=plan

# Apply development
gh workflow run terraform.yml \
  --repo rgcleanslage/iqq-infrastructure \
  --ref main \
  -f environment=dev \
  -f action=apply

# Plan production
gh workflow run terraform.yml \
  --repo rgcleanslage/iqq-infrastructure \
  --ref main \
  -f environment=prod \
  -f action=plan

# Apply production
gh workflow run terraform.yml \
  --repo rgcleanslage/iqq-infrastructure \
  --ref main \
  -f environment=prod \
  -f action=apply
```

#### SAM Service Deployment

```bash
# Deploy to development
gh workflow run ci-cd.yml \
  --repo rgcleanslage/iqq-lender-service \
  --ref main \
  -f environment=dev

# Deploy to production
gh workflow run ci-cd.yml \
  --repo rgcleanslage/iqq-lender-service \
  --ref main \
  -f environment=prod
```

### Option 3: Deployment Script

Create a helper script for easier deployments:

```bash
#!/bin/bash
# deploy.sh - Helper script for manual deployments

REPO=$1
ENV=$2
ACTION=$3

if [ -z "$REPO" ] || [ -z "$ENV" ]; then
    echo "Usage: ./deploy.sh <repo> <env> [action]"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh infrastructure dev plan"
    echo "  ./deploy.sh infrastructure dev apply"
    echo "  ./deploy.sh lender-service dev"
    echo "  ./deploy.sh providers prod"
    exit 1
fi

case $REPO in
    infrastructure)
        if [ -z "$ACTION" ]; then
            echo "Error: Terraform requires action (plan or apply)"
            exit 1
        fi
        gh workflow run terraform.yml \
            --repo rgcleanslage/iqq-infrastructure \
            --ref main \
            -f environment=$ENV \
            -f action=$ACTION
        echo "✓ Triggered Terraform $ACTION for $ENV environment"
        ;;
    lender-service|package-service|product-service|document-service|providers)
        gh workflow run ci-cd.yml \
            --repo rgcleanslage/iqq-$REPO \
            --ref main \
            -f environment=$ENV
        echo "✓ Triggered deployment of $REPO to $ENV environment"
        ;;
    *)
        echo "Unknown repository: $REPO"
        exit 1
        ;;
esac

echo ""
echo "View workflow status:"
echo "  gh run list --repo rgcleanslage/iqq-$REPO --limit 1"
```

Make it executable:
```bash
chmod +x deploy.sh
```

Usage:
```bash
# Terraform
./deploy.sh infrastructure dev plan
./deploy.sh infrastructure dev apply

# SAM services
./deploy.sh lender-service dev
./deploy.sh providers prod
```

## Deployment Workflow

### Recommended Process

#### For Development Environment

1. **Make changes** in a feature branch
2. **Create PR** to `develop` branch
3. **Review tests** - Tests run automatically on PR
4. **Merge PR** to `develop`
5. **Run plan** manually to review changes
   ```bash
   gh workflow run terraform.yml --repo rgcleanslage/iqq-infrastructure --ref main -f environment=dev -f action=plan
   ```
6. **Review plan output** in GitHub Actions
7. **Run apply** if plan looks good
   ```bash
   gh workflow run terraform.yml --repo rgcleanslage/iqq-infrastructure --ref main -f environment=dev -f action=apply
   ```

#### For Production Environment

1. **Test in dev** first
2. **Create PR** to `main` branch
3. **Review and approve** PR
4. **Merge to main**
5. **Run plan** for production
   ```bash
   gh workflow run terraform.yml --repo rgcleanslage/iqq-infrastructure --ref main -f environment=prod -f action=plan
   ```
6. **Review plan carefully**
7. **Get team approval** for production changes
8. **Run apply** with caution
   ```bash
   gh workflow run terraform.yml --repo rgcleanslage/iqq-infrastructure --ref main -f environment=prod -f action=apply
   ```

## Monitoring Deployments

### View Running Workflows

```bash
# List recent workflow runs
gh run list --repo rgcleanslage/iqq-infrastructure --limit 5

# Watch a specific run
gh run watch <run-id> --repo rgcleanslage/iqq-infrastructure

# View logs
gh run view <run-id> --repo rgcleanslage/iqq-infrastructure --log
```

### Check Deployment Status

```bash
# Check if deployment succeeded
gh run list --repo rgcleanslage/iqq-infrastructure --limit 1 --json conclusion --jq '.[0].conclusion'
```

## Pull Request Workflow

Pull requests still run tests and validation automatically:

1. **Create PR** to `develop` or `main`
2. **Tests run automatically** - No deployment
3. **Terraform plan runs** (for infrastructure PRs) - Shows what would change
4. **Review results** in PR checks
5. **Merge when ready** - Still no automatic deployment
6. **Manually trigger deployment** after merge

## Environment Protection

GitHub environments can be configured with protection rules:

### Development Environment
- No approval required
- Can be deployed by any team member

### Production Environment
- Requires approval from designated reviewers
- Can add deployment branch restrictions
- Can add wait timer before deployment

To configure:
1. Go to repository **Settings** > **Environments**
2. Click on environment name (development/production)
3. Add protection rules:
   - Required reviewers
   - Wait timer
   - Deployment branches

## Rollback Procedure

If a deployment causes issues:

### Terraform Rollback

1. **Revert the commit** that caused the issue
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

2. **Run plan** to see rollback changes
   ```bash
   gh workflow run terraform.yml --repo rgcleanslage/iqq-infrastructure --ref main -f environment=prod -f action=plan
   ```

3. **Apply the rollback**
   ```bash
   gh workflow run terraform.yml --repo rgcleanslage/iqq-infrastructure --ref main -f environment=prod -f action=apply
   ```

### SAM Rollback

1. **Find previous working version** in CloudFormation console
2. **Revert code** to previous commit
   ```bash
   git revert <commit-hash>
   git push origin main
   ```
3. **Redeploy** the previous version
   ```bash
   gh workflow run ci-cd.yml --repo rgcleanslage/iqq-lender-service --ref main -f environment=prod
   ```

## Troubleshooting

### Workflow Not Appearing

**Issue**: "Run workflow" button not visible

**Solution**: 
- Ensure you're on the `main` branch
- Check you have write access to the repository
- Refresh the page

### Workflow Fails Immediately

**Issue**: Workflow fails at authentication step

**Solution**:
- Verify `AWS_ROLE_ARN` secret is set correctly
- Check OIDC trust relationship in AWS
- Ensure role has necessary permissions

### Plan Shows Unexpected Changes

**Issue**: Terraform plan shows changes you didn't make

**Solution**:
- Check if someone else made manual changes in AWS console
- Review recent commits
- Check if state file is up to date
- Run `terraform refresh` locally to sync state

### Deployment Stuck

**Issue**: Deployment running for too long

**Solution**:
- Check CloudFormation console for stack status
- Look for resources waiting for manual intervention
- Cancel workflow and investigate the issue
- May need to manually fix resources in AWS console

## Best Practices

1. **Always plan before apply** - Review changes before applying
2. **Test in dev first** - Never deploy directly to production
3. **Use descriptive commit messages** - Makes it easier to track changes
4. **Document major changes** - Update documentation when making significant changes
5. **Coordinate with team** - Communicate before production deployments
6. **Monitor after deployment** - Check CloudWatch logs and metrics
7. **Keep PRs small** - Easier to review and rollback if needed
8. **Use feature flags** - For gradual rollouts of new features

## Security Considerations

- Manual deployments reduce risk of accidental changes
- OIDC authentication means no long-lived credentials
- Environment protection rules add approval gates
- All deployments are logged and auditable
- State locking prevents concurrent modifications

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform Workflow Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS SAM Deployment Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-deploying.html)

---

**Last Updated**: February 16, 2026  
**Workflow Type**: Manual Dispatch Only
