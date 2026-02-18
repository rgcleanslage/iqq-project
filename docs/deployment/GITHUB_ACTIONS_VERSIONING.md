# GitHub Actions Versioning Workflows

## Overview

This document describes the GitHub Actions workflows for managing API versioning across the iQQ platform. The workflows provide centralized orchestration from the root repository to deploy, deprecate, and sunset API versions across all service repositories.

**Date**: February 18, 2026  
**Status**: Task 4 Complete

## Architecture

### Repository Structure

```
root-repository (iqq-project)
├── .github/workflows/
│   ├── deploy-version.yml       # Centralized version deployment
│   ├── deprecate-version.yml    # Version deprecation
│   └── sunset-version.yml       # Version sunset/removal
├── config/
│   └── version-policy.json      # Centralized version configuration
└── scripts/
    ├── service-deploy-workflow.yml      # Service workflow template
    └── deploy-service-workflows.sh      # Deployment script

iqq-{service}-service (4 repositories)
└── .github/workflows/
    └── deploy.yml               # Service deployment workflow
```

### Workflow Orchestration

```
┌─────────────────────────────────────────────────────────────┐
│ Root Repository (iqq-project)                               │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ deploy-version.yml                                   │  │
│  │ - Validates version                                  │  │
│  │ - Triggers service deployments (parallel)            │  │
│  │ - Monitors deployment status                         │  │
│  │ - Updates API Gateway                                │  │
│  │ - Updates version policy                             │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Triggers via workflow_dispatch                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ iqq-package-  │   │ iqq-lender-   │   │ iqq-product-  │
│ service       │   │ service       │   │ service       │
│               │   │               │   │               │
│ deploy.yml    │   │ deploy.yml    │   │ deploy.yml    │
│ - Test        │   │ - Test        │   │ - Test        │
│ - Build       │   │ - Build       │   │ - Build       │
│ - Deploy SAM  │   │ - Deploy SAM  │   │ - Deploy SAM  │
│ - Update alias│   │ - Update alias│   │ - Update alias│
│ - Verify      │   │ - Verify      │   │ - Verify      │
└───────────────┘   └───────────────┘   └───────────────┘
```

## Workflows

### 1. Deploy Version Workflow

**File**: `.github/workflows/deploy-version.yml`  
**Trigger**: Manual (workflow_dispatch)  
**Purpose**: Deploy a specific API version across all services

#### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | choice | Yes | Version to deploy (v1, v2) |
| `services` | string | Yes | Services to deploy (comma-separated or "all") |
| `environment` | choice | Yes | Target environment (dev) |

#### Jobs

1. **validate-version**
   - Validates version exists in configuration
   - Checks version status (cannot deploy sunset versions)
   - Parses service list

2. **deploy-services**
   - Triggers deployment in each service repository
   - Runs in parallel (max 2 concurrent)
   - Monitors deployment status
   - Fails if any service deployment fails

3. **verify-deployments**
   - Tests all deployed services
   - Verifies HTTP 200 responses
   - Checks version headers

4. **update-api-gateway**
   - Verifies API Gateway stage exists
   - Triggers redeployment to pick up new Lambda versions

5. **update-version-policy**
   - Updates `lastDeployed` timestamp
   - Commits changes to repository

6. **notify-completion**
   - Provides deployment summary
   - Lists deployed endpoints

#### Usage

```bash
# Via GitHub UI
1. Go to Actions tab
2. Select "Deploy API Version"
3. Click "Run workflow"
4. Select version (v1 or v2)
5. Enter services (all, or package,lender,product,document)
6. Select environment (dev)
7. Click "Run workflow"

# Via GitHub CLI
gh workflow run deploy-version.yml \
  -f version=v1 \
  -f services=all \
  -f environment=dev
```

#### Example Output

```
✅ Version v1 validated (status: stable)
🚀 Triggering deployment for iqq-package-service
🚀 Triggering deployment for iqq-lender-service
🚀 Triggering deployment for iqq-product-service
🚀 Triggering deployment for iqq-document-service
📊 Monitoring deployments...
✅ All services deployed successfully
🧪 Testing deployed services...
✅ All services verified
🔄 Updating API Gateway...
✅ API Gateway redeployment complete
📝 Updating version policy...
✅ Version policy updated
```

### 2. Deprecate Version Workflow

**File**: `.github/workflows/deprecate-version.yml`  
**Trigger**: Manual (workflow_dispatch)  
**Purpose**: Mark a version as deprecated and update deprecation headers

#### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | choice | Yes | Version to deprecate (v1, v2) |
| `sunset_date` | string | Yes | Sunset date (YYYY-MM-DD) |
| `migration_guide_url` | string | Yes | Migration guide URL |

#### Jobs

1. **validate-deprecation**
   - Validates version exists
   - Ensures version is not current
   - Validates sunset date format
   - Checks sunset date is in future
   - Warns if less than 90 days notice

2. **update-version-policy**
   - Updates version status to "deprecated"
   - Sets sunset date
   - Sets migration guide URL
   - Commits changes

3. **deploy-updated-config**
   - Copies updated version policy to each service
   - Commits changes to service repositories
   - Triggers service deployments

4. **verify-deprecation-headers**
   - Tests all services
   - Verifies `X-API-Deprecated: true`
   - Verifies `X-API-Sunset-Date` header
   - Checks for `Warning` header

5. **notify-completion**
   - Provides deprecation summary
   - Lists next steps

#### Usage

```bash
# Via GitHub UI
1. Go to Actions tab
2. Select "Deprecate API Version"
3. Click "Run workflow"
4. Select version to deprecate
5. Enter sunset date (YYYY-MM-DD)
6. Enter migration guide URL
7. Click "Run workflow"

# Via GitHub CLI
gh workflow run deprecate-version.yml \
  -f version=v1 \
  -f sunset_date=2026-12-31 \
  -f migration_guide_url=https://docs.iqq.com/api/migration/v1-to-v2
```

#### Example Output

```
✅ Deprecation request validated
   Version: v1
   Current version: v2
   Sunset date: 2026-12-31T23:59:59Z
   Days until sunset: 317
📝 Updating version policy...
✅ Version policy updated
📝 Updating iqq-package-service...
📝 Updating iqq-lender-service...
📝 Updating iqq-product-service...
📝 Updating iqq-document-service...
🚀 Triggering service deployments...
🧪 Testing deprecation headers...
✅ X-API-Deprecated: true
✅ X-API-Sunset-Date: 2026-12-31T23:59:59Z
✅ Warning header present
```

### 3. Sunset Version Workflow

**File**: `.github/workflows/sunset-version.yml`  
**Trigger**: Manual (workflow_dispatch)  
**Purpose**: Remove a version from production (delete stage and aliases)

#### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | choice | Yes | Version to sunset (v1, v2) |
| `confirm` | string | Yes | Type "CONFIRM" to proceed |

#### Jobs

1. **validate-sunset**
   - Validates confirmation input
   - Ensures version exists
   - Ensures version is not current
   - Warns if not deprecated
   - Checks if sunset date has passed

2. **check-usage**
   - Checks CloudWatch metrics
   - Warns about recent usage
   - Recommends manual verification

3. **remove-api-gateway-stage**
   - Deletes API Gateway stage
   - Verifies stage removal

4. **cleanup-lambda-aliases**
   - Deletes Lambda aliases from all services
   - Runs in parallel
   - Verifies alias removal

5. **update-version-policy**
   - Updates version status to "sunset"
   - Sets `sunsetAt` timestamp
   - Commits changes

6. **archive-documentation**
   - Creates archive directory
   - Generates archive README
   - Commits archive

7. **notify-completion**
   - Provides sunset summary
   - Lists post-sunset actions

#### Usage

```bash
# Via GitHub UI
1. Go to Actions tab
2. Select "Sunset API Version"
3. Click "Run workflow"
4. Select version to sunset
5. Type "CONFIRM" in confirmation field
6. Click "Run workflow"

# Via GitHub CLI
gh workflow run sunset-version.yml \
  -f version=v1 \
  -f confirm=CONFIRM
```

#### Example Output

```
✅ Sunset confirmed
✅ Sunset request validated
   Version: v1
   Status: deprecated
   Current version: v2
📊 Checking usage metrics...
⚠️  Manual verification recommended
🗑️  Removing API Gateway stage: v1
✅ API Gateway stage v1 removed
🗑️  Removing Lambda alias v1 from iqq-package-service-dev
🗑️  Removing Lambda alias v1 from iqq-lender-service-dev
🗑️  Removing Lambda alias v1 from iqq-product-service-dev
🗑️  Removing Lambda alias v1 from iqq-document-service-dev
✅ All Lambda aliases removed
📝 Updating version policy...
✅ Version policy updated
📦 Creating documentation archive...
✅ Archive created
```

### 4. Service Deployment Workflow

**File**: `.github/workflows/deploy.yml` (in each service repository)  
**Trigger**: workflow_dispatch (from root repository or manual)  
**Purpose**: Deploy a single service with version alias

#### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Version to deploy (v1, v2) |
| `environment` | string | Yes | Target environment (dev) |
| `triggered_by` | string | No | Triggering source |

#### Jobs

1. **validate**
   - Sets deployment configuration
   - Validates version in version policy

2. **test**
   - Runs linter
   - Runs unit tests
   - Uploads coverage

3. **build**
   - Builds TypeScript
   - Builds SAM application
   - Uploads build artifacts

4. **deploy**
   - Downloads build artifacts
   - Deploys with SAM
   - Gets function ARN

5. **update-alias**
   - Publishes new Lambda version
   - Updates or creates alias
   - Verifies alias

6. **verify**
   - Tests Lambda function
   - Verifies response

7. **notify**
   - Provides deployment summary

#### Usage

```bash
# Triggered automatically by root repository
# Or manually via GitHub UI/CLI

gh workflow run deploy.yml \
  --repo rgcleanslage/iqq-package-service \
  -f version=v1 \
  -f environment=dev \
  -f triggered_by=manual
```

## Setup Instructions

### Prerequisites

1. **GitHub Personal Access Token (PAT)**
   - Create PAT with `repo` and `workflow` scopes
   - Store as `PAT_TOKEN` secret in root repository

2. **AWS Credentials**
   - Configure OIDC or IAM role
   - Store as `AWS_ROLE_ARN` secret in all repositories

3. **SAM Deployment Bucket**
   - Create S3 bucket for SAM artifacts
   - Store as `SAM_DEPLOYMENT_BUCKET` secret in service repositories

### Step 1: Deploy Service Workflows

```bash
# From root repository
cd scripts
chmod +x deploy-service-workflows.sh
./deploy-service-workflows.sh

# Review generated workflows
for service in package lender product document; do
  cat ../iqq-${service}-service/.github/workflows/deploy.yml
done

# Push changes to service repositories
for service in package lender product document; do
  cd ../iqq-${service}-service
  git push origin main
  cd -
done
```

### Step 2: Configure GitHub Secrets

#### Root Repository Secrets

```bash
# Set PAT token
gh secret set PAT_TOKEN --repo rgcleanslage/iqq-project

# Set AWS role ARN
gh secret set AWS_ROLE_ARN --repo rgcleanslage/iqq-project
```

#### Service Repository Secrets

```bash
# For each service
for service in package lender product document; do
  gh secret set AWS_ROLE_ARN --repo rgcleanslage/iqq-${service}-service
  gh secret set SAM_DEPLOYMENT_BUCKET --repo rgcleanslage/iqq-${service}-service
done
```

### Step 3: Test Workflows

#### Test Service Deployment

```bash
# Test single service
gh workflow run deploy.yml \
  --repo rgcleanslage/iqq-package-service \
  -f version=v1 \
  -f environment=dev \
  -f triggered_by=manual

# Monitor workflow
gh run watch --repo rgcleanslage/iqq-package-service
```

#### Test Centralized Deployment

```bash
# Test full deployment
gh workflow run deploy-version.yml \
  --repo rgcleanslage/iqq-project \
  -f version=v1 \
  -f services=all \
  -f environment=dev

# Monitor workflow
gh run watch --repo rgcleanslage/iqq-project
```

## Required Secrets

### Root Repository (iqq-project)

| Secret | Description | Example |
|--------|-------------|---------|
| `PAT_TOKEN` | GitHub Personal Access Token | `ghp_...` |
| `AWS_ROLE_ARN` | AWS IAM Role ARN for OIDC | `arn:aws:iam::785826687678:role/...` |

### Service Repositories (all 4)

| Secret | Description | Example |
|--------|-------------|---------|
| `AWS_ROLE_ARN` | AWS IAM Role ARN for OIDC | `arn:aws:iam::785826687678:role/...` |
| `SAM_DEPLOYMENT_BUCKET` | S3 bucket for SAM artifacts | `iqq-sam-deployments-785826687678` |

## Workflow Permissions

### Root Repository Workflows

```yaml
permissions:
  id-token: write    # For AWS OIDC
  contents: read     # For checkout
  actions: write     # For triggering workflows
```

### Service Repository Workflows

```yaml
permissions:
  id-token: write    # For AWS OIDC
  contents: read     # For checkout
```

## Monitoring and Troubleshooting

### View Workflow Runs

```bash
# List recent runs
gh run list --repo rgcleanslage/iqq-project

# View specific run
gh run view <run-id> --repo rgcleanslage/iqq-project

# View logs
gh run view <run-id> --log --repo rgcleanslage/iqq-project
```

### Common Issues

#### 1. PAT Token Expired

**Error**: `Resource not accessible by integration`

**Solution**: Regenerate PAT and update secret

```bash
gh secret set PAT_TOKEN --repo rgcleanslage/iqq-project
```

#### 2. Service Deployment Timeout

**Error**: `Deployment timed out after 60 attempts`

**Solution**: Check service repository workflow status manually

```bash
gh run list --repo rgcleanslage/iqq-package-service
```

#### 3. AWS Credentials Invalid

**Error**: `Unable to locate credentials`

**Solution**: Verify AWS_ROLE_ARN secret and OIDC configuration

```bash
gh secret list --repo rgcleanslage/iqq-project
```

## Best Practices

### 1. Version Deployment

- Always deploy to all services together
- Test thoroughly before deprecation
- Monitor CloudWatch metrics after deployment

### 2. Deprecation

- Provide at least 90 days notice
- Update migration guides before deprecation
- Notify API consumers via email/documentation

### 3. Sunset

- Verify zero usage before sunset
- Archive documentation
- Keep Lambda versions for rollback

### 4. Rollback

If deployment fails:

```bash
# Redeploy previous version
gh workflow run deploy-version.yml \
  -f version=v1 \
  -f services=all \
  -f environment=dev
```

## Version Lifecycle Example

### 1. Initial Deployment (v1)

```bash
gh workflow run deploy-version.yml \
  -f version=v1 \
  -f services=all \
  -f environment=dev
```

### 2. Deploy New Version (v2)

```bash
gh workflow run deploy-version.yml \
  -f version=v2 \
  -f services=all \
  -f environment=dev
```

### 3. Deprecate Old Version (v1)

```bash
gh workflow run deprecate-version.yml \
  -f version=v1 \
  -f sunset_date=2026-12-31 \
  -f migration_guide_url=https://docs.iqq.com/api/migration/v1-to-v2
```

### 4. Sunset Old Version (v1)

```bash
# After sunset date and zero usage
gh workflow run sunset-version.yml \
  -f version=v1 \
  -f confirm=CONFIRM
```

## Related Documentation

- [API Versioning Setup](../api/API_VERSIONING_SETUP.md)
- [API Version Headers](../api/API_VERSION_HEADERS.md)
- [Terraform Implementation](./API_VERSIONING_TERRAFORM.md)
- [GitHub OIDC Setup](./GITHUB_OIDC_SETUP.md)
- [Task Tracking](../../.kiro/specs/api-versioning/tasks.md)

---

**Status**: ✅ Complete  
**Date**: February 18, 2026  
**Next Task**: Task 5 - Create release branches
