# Deployment Documentation

Complete deployment documentation for the iQQ Insurance Quoting Platform.

## Quick Start

### For New Deployments
1. [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Complete deployment guide
2. [MANUAL_DEPLOYMENT_GUIDE.md](./MANUAL_DEPLOYMENT_GUIDE.md) - Manual deployment steps
3. [TESTING_QUICK_START.md](./TESTING_QUICK_START.md) - Test your deployment

### For API Versioning
1. [API_VERSIONING_WITH_GITHUB_RELEASES.md](./API_VERSIONING_WITH_GITHUB_RELEASES.md) - Complete versioning guide
2. [ADD_NEW_VERSION_GUIDE.md](./ADD_NEW_VERSION_GUIDE.md) - Add new API versions
3. [ALIAS_MANAGEMENT.md](./ALIAS_MANAGEMENT.md) - Lambda alias management

### For CI/CD Setup
1. [CICD_SETUP_GUIDE.md](./CICD_SETUP_GUIDE.md) - CI/CD pipeline configuration
2. [GITHUB_OIDC_SETUP.md](./GITHUB_OIDC_SETUP.md) - GitHub OIDC for AWS
3. [GITHUB_ACTIONS_VERSIONING.md](./GITHUB_ACTIONS_VERSIONING.md) - GitHub Actions workflows

## Documentation Index

### Core Deployment
- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - Comprehensive deployment guide with all steps
- **[MANUAL_DEPLOYMENT_GUIDE.md](./MANUAL_DEPLOYMENT_GUIDE.md)** - Manual deployment without automation
- **[TESTING_QUICK_START.md](./TESTING_QUICK_START.md)** - Quick start for testing deployments

### API Versioning
- **[API_VERSIONING_WITH_GITHUB_RELEASES.md](./API_VERSIONING_WITH_GITHUB_RELEASES.md)** - Complete versioning guide
- **[ADD_NEW_VERSION_GUIDE.md](./ADD_NEW_VERSION_GUIDE.md)** - How to add new API versions
- **[ADD_NEW_VERSION_WORKFLOW_GUIDE.md](./ADD_NEW_VERSION_WORKFLOW_GUIDE.md)** - Workflow guide for adding versions
- **[ALIAS_MANAGEMENT.md](./ALIAS_MANAGEMENT.md)** - Lambda alias management
- **[RELEASE_BRANCH_STRATEGY.md](./RELEASE_BRANCH_STRATEGY.md)** - Release branch strategy
- **[MIGRATION_GUIDE_AUTOMATION.md](./MIGRATION_GUIDE_AUTOMATION.md)** - Automated migration guides

### CI/CD & Automation
- **[CICD_SETUP_GUIDE.md](./CICD_SETUP_GUIDE.md)** - Complete CI/CD pipeline setup
- **[GITHUB_ACTIONS_VERSIONING.md](./GITHUB_ACTIONS_VERSIONING.md)** - GitHub Actions for version management
- **[GITHUB_OIDC_SETUP.md](./GITHUB_OIDC_SETUP.md)** - GitHub OIDC configuration for AWS
- **[OIDC_SETUP_REQUIRED.md](./OIDC_SETUP_REQUIRED.md)** - OIDC setup requirements

### Infrastructure
- **[API_VERSIONING_TERRAFORM.md](./API_VERSIONING_TERRAFORM.md)** - Terraform configuration for versioning
- **[REMOTE_STATE_SETUP.md](./REMOTE_STATE_SETUP.md)** - Terraform remote state configuration
- **[HTTP_PROVIDER_MIGRATION.md](./HTTP_PROVIDER_MIGRATION.md)** - HTTP provider migration guide

### Security
- **[SECRETS_MANAGER_SETUP.md](./SECRETS_MANAGER_SETUP.md)** - AWS Secrets Manager configuration
- **[COGNITO_AUTHORIZER_ISSUE.md](./COGNITO_AUTHORIZER_ISSUE.md)** - Cognito authorizer notes

### Service Integration
- **[PACKAGE_SERVICE_INTEGRATION.md](./PACKAGE_SERVICE_INTEGRATION.md)** - Package service integration guide

## Deployment Workflows

The platform uses 5 GitHub Actions workflows for version management:

### 1. Add New Version
**Workflow:** `add-new-version.yml`

Creates a new API version with:
- GitHub Release with version metadata
- API Gateway stage
- Lambda permissions
- Release branches in all repositories
- Usage plan configuration

```bash
gh workflow run add-new-version.yml -f new_version=v10 -f status=planned
```

### 2. Deploy Version
**Workflow:** `deploy-version.yml`

Deploys Lambda functions for a version:
- Triggers service deployments
- Creates Lambda aliases
- Updates API Gateway configuration
- Adds Lambda permissions
- Verifies endpoints
- Updates release metadata

```bash
gh workflow run deploy-version.yml -f version=v10 -f environment=dev -f deploy_all=true
```

### 3. Update Version Status
**Workflow:** `update-version-status.yml`

Promotes versions through lifecycle:
- planned → alpha → beta → stable
- Updates GitHub Release
- Manages pre-release flag
- Optionally marks as current version

```bash
gh workflow run update-version-status.yml -f version=v10 -f new_status=alpha
```

### 4. Deprecate Version
**Workflow:** `deprecate-version.yml`

Marks a version as deprecated:
- Sets deprecation date
- Sets sunset date
- Updates GitHub Release
- Adds deprecation headers to responses

```bash
gh workflow run deprecate-version.yml -f version=v1 -f sunset_days=90
```

### 5. Sunset Version
**Workflow:** `sunset-version.yml`

Removes a deprecated version:
- Deletes API Gateway stage
- Removes Lambda aliases
- Updates GitHub Release to sunset status
- Removes from usage plans

```bash
gh workflow run sunset-version.yml -f version=v1
```

## Version Lifecycle

```
planned → alpha → beta → stable → deprecated → sunset
```

### Status Descriptions

- **planned** - Version created but not yet deployed
- **alpha** - Early testing phase, may have breaking changes
- **beta** - Feature complete, testing in progress
- **stable** - Production ready, recommended for use
- **deprecated** - Still available but scheduled for removal
- **sunset** - No longer available

## Deployment Architecture

```
GitHub Actions
     ↓
AWS (via OIDC)
     ↓
┌────────────────────────────────────┐
│  Lambda Services (4)               │
│  - Package Service                 │
│  - Lender Service                  │
│  - Product Service                 │
│  - Document Service                │
└────────────────────────────────────┘
     ↓
┌────────────────────────────────────┐
│  Lambda Aliases                    │
│  - v1, v2, v3, ..., v9            │
└────────────────────────────────────┘
     ↓
┌────────────────────────────────────┐
│  API Gateway                       │
│  - Stages: v1, v2, ..., v9        │
│  - Usage Plans                     │
│  - Lambda Permissions              │
└────────────────────────────────────┘
```

## Environment Variables

Services use environment variables for version metadata:

```bash
VERSION_STATUS=stable
VERSION_SUNSET_DATE=null
VERSION_MIGRATION_GUIDE=https://docs.iqq.com/api/migration
VERSION_CURRENT=v1
```

These are set during deployment and included in API responses.

## Best Practices

### Version Management
1. Always create versions in `planned` status first
2. Test thoroughly in `alpha` and `beta` before promoting to `stable`
3. Give users 90 days notice before sunsetting a version
4. Keep at least one `stable` version available at all times

### Deployment
1. Deploy to `alpha` versions first for testing
2. Use `deploy_all=true` to deploy all services together
3. Monitor CloudWatch logs after deployment
4. Verify endpoints with the built-in verification step

### Security
1. Store all secrets in AWS Secrets Manager
2. Use GitHub OIDC for AWS authentication (no long-lived credentials)
3. Rotate API keys regularly
4. Review Lambda permissions after each deployment

### Monitoring
1. Check GitHub Actions workflow runs for failures
2. Monitor CloudWatch logs: `/aws/lambda/iqq-*-service-dev`
3. Review API Gateway metrics for each stage
4. Track usage plan consumption

## Troubleshooting

### Deployment Failures

**Service deployment timeout:**
- Check service repository workflow runs
- Review CloudWatch logs for the service
- Verify SAM template is valid

**Verification step fails:**
- Check if Lambda aliases exist
- Verify API Gateway stage configuration
- Ensure Lambda permissions are correct
- Check if secrets exist in Secrets Manager

**Permission errors:**
- Verify GitHub OIDC role has correct permissions
- Check Lambda execution role permissions
- Ensure API Gateway has permission to invoke Lambda

### Version Issues

**Version not found:**
- Verify GitHub Release exists with tag `api-{version}`
- Check if release branches were created
- Ensure API Gateway stage exists

**Endpoints return 500:**
- Check if Lambda aliases exist for the version
- Verify Lambda permissions for API Gateway
- Review CloudWatch logs for errors

**Deprecation headers not showing:**
- Verify version status in GitHub Release
- Check Lambda environment variables
- Ensure response-builder.ts is using env vars

## Support

### Documentation
- [API Versioning Guide](./API_VERSIONING_WITH_GITHUB_RELEASES.md)
- [CI/CD Setup](./CICD_SETUP_GUIDE.md)
- [Secrets Management](./SECRETS_MANAGER_SETUP.md)

### Logs
- GitHub Actions: Check workflow run logs
- Lambda: `/aws/lambda/iqq-*-service-dev`
- API Gateway: CloudWatch Logs for each stage

### Commands

```bash
# List workflow runs
gh run list --workflow=deploy-version.yml

# Watch a workflow run
gh run watch <run-id>

# View Lambda logs
aws logs tail /aws/lambda/iqq-package-service-dev --follow

# List API Gateway stages
aws apigateway get-stages --rest-api-id r8ukhidr1m

# List Lambda aliases
aws lambda list-aliases --function-name iqq-package-service-dev
```

---

**Last Updated:** February 19, 2026  
**Status:** Production Ready ✅
