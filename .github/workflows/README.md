# GitHub Actions CI/CD Setup

This document explains the GitHub Actions workflows for the iQQ Platform.

## Overview

The platform uses separate workflows for each repository:
- **SAM Services** (5 repos): Test, build, and deploy Lambda functions
- **Terraform Infrastructure** (1 repo): Validate, plan, and apply infrastructure changes

## Workflows

### SAM Service Workflows

Each SAM service (providers, lender, package, product, document) has the same workflow structure:

#### Jobs

1. **test** - Run unit tests
   - Checkout code
   - Setup Node.js 20.x
   - Install dependencies
   - Run tests
   - Upload coverage to Codecov (optional)

2. **build** - Build SAM application
   - Checkout code
   - Setup Node.js and SAM CLI
   - Install dependencies
   - Build with `sam build`
   - Upload build artifacts

3. **deploy-dev** - Deploy to development (on `develop` branch push)
   - Download build artifacts
   - Configure AWS credentials
   - Deploy with `sam deploy`
   - Stack name: `iqq-{service}-dev`

4. **deploy-prod** - Deploy to production (on `main` branch push)
   - Download build artifacts
   - Configure AWS credentials
   - Deploy with `sam deploy`
   - Stack name: `iqq-{service}-prod`

#### Triggers

- **Push** to `main` or `develop` branches
- **Pull Request** to `main` or `develop` branches
- **Manual** via workflow_dispatch

### Terraform Infrastructure Workflow

The infrastructure repository has a more complex workflow:

#### Jobs

1. **validate** - Validate Terraform code
   - Format check (`terraform fmt`)
   - Initialize without backend
   - Validate syntax

2. **plan-dev** - Plan development changes
   - Initialize with backend
   - Run `terraform plan` with dev variables
   - Upload plan artifact
   - Comment plan on PR (if applicable)

3. **plan-prod** - Plan production changes
   - Initialize with backend
   - Run `terraform plan` with prod variables
   - Upload plan artifact

4. **apply-dev** - Apply to development (on `develop` branch push)
   - Download plan artifact
   - Apply changes with `terraform apply`
   - Upload outputs as artifact
   - Requires manual approval (environment protection)

5. **apply-prod** - Apply to production (on `main` branch push)
   - Download plan artifact
   - Apply changes with `terraform apply`
   - Upload outputs as artifact
   - Seed DynamoDB with provider data
   - Requires manual approval (environment protection)

## Required Secrets

Configure these secrets in each repository's Settings > Secrets and variables > Actions:

### AWS Credentials
- `AWS_ACCESS_KEY_ID` - AWS access key for deployment
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for deployment
- `SAM_DEPLOYMENT_BUCKET` - S3 bucket for SAM artifacts (e.g., `my-sam-deployments`)

### Optional
- `CODECOV_TOKEN` - Token for Codecov integration (if using coverage reports)

## Environment Protection Rules

Set up environment protection rules in Settings > Environments:

### Development Environment
- **Name:** `development`
- **Protection rules:**
  - Required reviewers: 0 (optional)
  - Wait timer: 0 minutes
  - Deployment branches: `develop` only

### Production Environment
- **Name:** `production`
- **Protection rules:**
  - Required reviewers: 1+ (recommended)
  - Wait timer: 5 minutes (recommended)
  - Deployment branches: `main` only

## Deployment Flow

### Development Deployment

1. Create feature branch from `develop`
2. Make changes and commit
3. Push to GitHub
4. Create PR to `develop`
5. GitHub Actions runs tests and builds
6. Review and merge PR
7. Automatic deployment to development environment

### Production Deployment

1. Create PR from `develop` to `main`
2. GitHub Actions runs tests and builds
3. Review changes and Terraform plan
4. Merge PR to `main`
5. Manual approval required (if configured)
6. Automatic deployment to production environment

## Deployment Order

**Critical:** Deploy services before infrastructure!

### First Time Setup

1. **Deploy all SAM services** (in any order):
   ```bash
   # Push to develop branch in each repo
   git push origin develop
   ```

2. **Deploy infrastructure** (after all services are deployed):
   ```bash
   # Push to develop branch in infrastructure repo
   git push origin develop
   ```

### Subsequent Deployments

- **Service changes:** Deploy individual services as needed
- **Infrastructure changes:** Deploy infrastructure after service changes
- **Both:** Deploy services first, then infrastructure

## Branch Strategy

### Recommended Git Flow

```
main (production)
  └── develop (development)
       └── feature/* (feature branches)
```

### Branch Rules

- `main` - Production-ready code only
- `develop` - Integration branch for development
- `feature/*` - Feature development branches

### Protection Rules

Configure in Settings > Branches:

#### Main Branch
- Require pull request reviews (1+)
- Require status checks to pass
- Require branches to be up to date
- Include administrators

#### Develop Branch
- Require pull request reviews (optional)
- Require status checks to pass
- Require branches to be up to date

## Monitoring Deployments

### GitHub Actions UI

1. Go to repository > Actions tab
2. View workflow runs
3. Click on a run to see job details
4. View logs for each step

### AWS Console

1. **SAM Services:**
   - CloudFormation > Stacks
   - Lambda > Functions
   - CloudWatch > Logs

2. **Terraform Infrastructure:**
   - CloudFormation > Stacks (if using)
   - API Gateway > APIs
   - Cognito > User Pools
   - DynamoDB > Tables

## Troubleshooting

### Common Issues

#### 1. SAM Deployment Fails

**Error:** "Unable to upload artifact"

**Solution:** Ensure `SAM_DEPLOYMENT_BUCKET` secret is set and bucket exists

```bash
# Create bucket if needed
aws s3 mb s3://my-sam-deployments --region us-east-1
```

#### 2. Terraform Plan Fails

**Error:** "Backend initialization required"

**Solution:** Configure Terraform backend in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "iqq-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}
```

#### 3. Tests Fail

**Error:** "npm test failed"

**Solution:** Run tests locally first:

```bash
npm ci
npm test
```

#### 4. AWS Credentials Invalid

**Error:** "Unable to locate credentials"

**Solution:** Verify secrets are set correctly in repository settings

### Debug Mode

Enable debug logging by setting repository secrets:
- `ACTIONS_STEP_DEBUG` = `true`
- `ACTIONS_RUNNER_DEBUG` = `true`

## Best Practices

### 1. Test Locally First

Before pushing, test locally:

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

### 2. Use Pull Requests

- Never push directly to `main` or `develop`
- Always create PRs for code review
- Wait for CI checks to pass

### 3. Review Terraform Plans

- Always review Terraform plans before applying
- Check for unexpected resource changes
- Verify variable values

### 4. Monitor Deployments

- Watch CloudWatch Logs during deployment
- Check Lambda function metrics
- Verify API Gateway endpoints

### 5. Rollback Strategy

If deployment fails:

```bash
# SAM services - redeploy previous version
sam deploy --stack-name iqq-{service}-prod --no-confirm-changeset

# Terraform - revert changes
git revert <commit-hash>
git push origin main
```

## Cost Optimization

### GitHub Actions Minutes

- Free tier: 2,000 minutes/month for private repos
- Public repos: Unlimited minutes
- Optimize by:
  - Using caching for dependencies
  - Running tests in parallel
  - Skipping unnecessary jobs

### AWS Resources

- Use `--no-fail-on-empty-changeset` to avoid unnecessary deployments
- Clean up old CloudFormation stacks
- Delete unused S3 artifacts

## Security

### Secrets Management

- Never commit secrets to code
- Use GitHub Secrets for sensitive data
- Rotate AWS credentials regularly
- Use IAM roles with least privilege

### Code Scanning

Enable GitHub security features:
- Dependabot alerts
- Code scanning (CodeQL)
- Secret scanning

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS SAM CLI Documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-command-reference.html)
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)

---

**Last Updated:** February 16, 2026  
**Version:** 1.0.0
