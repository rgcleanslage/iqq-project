---
inclusion: auto
description: Deployment practices including Terraform + SAM hybrid approach, deployment order, TypeScript build process, and CI/CD workflows
---

# Deployment Practices

This project uses a hybrid deployment approach: Terraform for infrastructure, SAM for Lambda functions.

## Deployment Architecture

### Terraform (Infrastructure)
Manages AWS resources that change infrequently:
- API Gateway
- Cognito User Pool
- DynamoDB tables
- Step Functions state machines
- Lambda versioning & aliases
- CloudWatch alarms
- IAM roles (infrastructure-level)

### AWS SAM (Lambda Functions)
Manages Lambda functions that change frequently:
- Function code
- Function configuration
- IAM execution roles
- CloudWatch log groups
- Environment variables

## Deployment Order

**CRITICAL**: Always deploy in this order to avoid dependency issues.

### 1. Infrastructure (Terraform)
```bash
cd iqq-infrastructure

# Initialize (first time only)
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply

# Get outputs
terraform output
```

**Outputs needed for SAM**:
- API Gateway ID
- DynamoDB table name
- Step Functions ARN
- Cognito User Pool ID

### 2. Provider Services (SAM)
```bash
cd iqq-providers

# Install dependencies
npm install

# Build TypeScript
npm run build

# Build SAM package
sam build

# Deploy
sam deploy

# Get outputs
aws cloudformation describe-stacks \
  --stack-name iqq-providers \
  --query 'Stacks[0].Outputs'
```

**Outputs needed for Terraform**:
- Provider Lambda ARNs
- Provider Function URLs
- Adapter Lambda ARNs
- Authorizer Lambda ARN

### 3. Microservices (SAM - each service)
```bash
# For each service: lender, product, package, document
cd iqq-{service}-service

npm install
npm run build
sam build
sam deploy
```

### 4. Update DynamoDB (if needed)
```bash
cd scripts
npm install
npx ts-node seed-dynamodb.ts
```

## Build Process

### TypeScript Compilation

**CRITICAL**: Always build TypeScript locally before SAM build.

```bash
# Build TypeScript
npm run build

# This creates dist/ folder with compiled JavaScript
```

### SAM Build with Makefile

Each service has a `Makefile` that copies pre-built code:

```makefile
build-FunctionName:
	cp -r dist $(ARTIFACTS_DIR)/
	cp package.json $(ARTIFACTS_DIR)/
	cd $(ARTIFACTS_DIR) && npm install --production
```

SAM template references the Makefile:

```yaml
Metadata:
  BuildMethod: makefile
```

**Why this approach?**
- SAM's esbuild doesn't handle all TypeScript features
- Pre-building ensures consistent compilation
- Faster builds (no compilation during sam build)
- Better error messages during development

### Build Commands

```bash
# Clean build
rm -rf dist/ .aws-sam/
npm run build
sam build

# Quick rebuild (if only code changed)
npm run build
sam build

# Full rebuild (if dependencies changed)
rm -rf node_modules/ dist/ .aws-sam/
npm install
npm run build
sam build
```

## Deployment Environments

### Current Environment
- **Environment**: dev
- **Region**: us-east-1
- **Account**: 785826687678

### Environment Variables

**Terraform** (`terraform.tfvars`):
```hcl
environment = "dev"
aws_region  = "us-east-1"
project_name = "iqq"
```

**SAM** (`samconfig.toml`):
```toml
[default.deploy.parameters]
stack_name = "iqq-service-name"
region = "us-east-1"
parameter_overrides = "Environment=dev"
```

## GitHub Actions CI/CD

### Workflow Files
Each service has `.github/workflows/deploy-to-dev.yml`:

```yaml
name: Deploy to Dev

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      
      - name: Install dependencies
        run: npm install
      
      - name: Build TypeScript
        run: npm run build
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::785826687678:role/github-actions-role
          aws-region: us-east-1
      
      - name: SAM Build
        run: sam build
      
      - name: SAM Deploy
        run: sam deploy --no-confirm-changeset --no-fail-on-empty-changeset
```

### GitHub OIDC Setup

**Required**: GitHub Actions uses OIDC to assume AWS IAM role (no access keys).

```terraform
# iqq-infrastructure/modules/github-oidc/main.tf
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["..."]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:rgcleanslage/*:*"
        }
      }
    }]
  })
}
```

## Manual Deployment

### Deploy Single Service

```bash
cd iqq-lender-service

# Build and deploy
npm run build
sam build
sam deploy

# Deploy with specific parameters
sam deploy --parameter-overrides Environment=dev LogLevel=DEBUG
```

### Deploy All Services

```bash
# Script to deploy all services
for service in lender product package document; do
  echo "Deploying $service service..."
  cd iqq-${service}-service
  npm install
  npm run build
  sam build
  sam deploy
  cd ..
done
```

### Deploy Infrastructure Only

```bash
cd iqq-infrastructure
terraform apply -target=module.api_gateway
terraform apply -target=module.dynamodb
```

## Rollback Procedures

### SAM Rollback

```bash
# List stack events
aws cloudformation describe-stack-events \
  --stack-name iqq-lender-service-dev \
  --max-items 20

# Rollback to previous version
aws cloudformation rollback-stack \
  --stack-name iqq-lender-service-dev
```

### Terraform Rollback

```bash
# Revert to previous state
terraform state pull > backup.tfstate
terraform apply -target=module.api_gateway

# Or use version control
git revert HEAD
terraform apply
```

### Lambda Version Rollback

```bash
# Update alias to previous version
aws lambda update-alias \
  --function-name iqq-lender-dev \
  --name live \
  --function-version 5
```

## Testing After Deployment

### Smoke Tests

```bash
# Test authorizer
curl -X GET https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-api-key: $API_KEY"

# Expected: 200 OK

# Test without token
curl -X GET https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender \
  -H "x-api-key: $API_KEY"

# Expected: 401 Unauthorized

# Test without API key
curl -X GET https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Expected: 403 Forbidden
```

### Integration Tests

```bash
# Run SoapUI tests
cd docs/testing
./test-all-endpoints.sh
```

## Monitoring Deployments

### CloudWatch Logs

```bash
# Tail Lambda logs
aws logs tail /aws/lambda/iqq-lender-dev --follow

# Filter for errors
aws logs tail /aws/lambda/iqq-lender-dev --follow --filter-pattern "ERROR"
```

### CloudFormation Events

```bash
# Watch stack deployment
aws cloudformation describe-stack-events \
  --stack-name iqq-lender-service-dev \
  --max-items 10
```

### X-Ray Traces

```bash
# Get recent traces
aws xray get-trace-summaries \
  --start-time $(date -u -d '5 minutes ago' +%s) \
  --end-time $(date -u +%s)
```

## Common Deployment Issues

### Issue: "Template does not have any APIs"

**Cause**: SAM template doesn't include API Gateway events (managed by Terraform)

**Solution**: Use `sam local invoke` instead of `sam local start-api`

```bash
sam local invoke FunctionName -e events/test-event.json
```

### Issue: "Runtime.ImportModuleError"

**Cause**: TypeScript not compiled before SAM build

**Solution**: Build TypeScript first

```bash
npm run build
sam build
sam deploy
```

### Issue: "Resource already exists"

**Cause**: CloudFormation stack already exists

**Solution**: Update existing stack

```bash
sam deploy --no-confirm-changeset
```

### Issue: "Insufficient permissions"

**Cause**: IAM role missing permissions

**Solution**: Check execution role in SAM template

```yaml
Policies:
  - CloudWatchLogsFullAccess
  - AWSXRayDaemonWriteAccess
  - DynamoDBCrudPolicy:
      TableName: !Ref TableName
```

## Deployment Checklist

Before deploying:
- [ ] Code reviewed and tested locally
- [ ] TypeScript compiled (`npm run build`)
- [ ] Unit tests passing (`npm test`)
- [ ] Environment variables configured
- [ ] Dependencies updated (`npm install`)
- [ ] SAM template validated (`sam validate`)
- [ ] Terraform plan reviewed (`terraform plan`)

After deploying:
- [ ] Smoke tests passing
- [ ] CloudWatch logs show no errors
- [ ] X-Ray traces look healthy
- [ ] API Gateway endpoints responding
- [ ] DynamoDB tables accessible
- [ ] Step Functions executing successfully

## API Versioning with GitHub Releases

### Version Lifecycle

All API versions are tracked through GitHub Releases on the root repository with tag format `api-{version}`:

```
planned → alpha → beta → stable → deprecated → sunset
```

**Current Version**: v9 (latest release)

### Creating a New Version (v10)

Use GitHub Actions workflows to manage versions:

#### 1. Add New API Version

**Workflow**: `.github/workflows/add-new-version.yml`

```bash
# Go to: Actions → Add New API Version → Run workflow
Inputs:
  new_version: v10
  status: planned
  migration_guide_url: (optional)
```

**What it does**:
- Creates GitHub Release `api-v10` with metadata
- Generates migration guide template
- Creates API Gateway stage for v10
- Adds Lambda permissions for all services
- Creates `release/v10` branches in all service repos

#### 2. Update Version Status

**Workflow**: `.github/workflows/update-version-status.yml`

```bash
# Promote through lifecycle
Actions → Update Version Status → Run workflow
  version: v10
  new_status: alpha  # or beta, stable
  make_current: false  # true only for stable
```

#### 3. Deploy API Version

**Workflow**: `.github/workflows/deploy-version.yml`

```bash
# Deploy all services for v10
Actions → Deploy API Version → Run workflow
  version: v10
  deploy_all: true
  environment: dev
```

**What it does**:
- Triggers deployment in each service repo
- Tests all endpoints
- Redeploys API Gateway stage
- Updates release metadata with deploy timestamp

#### 4. Deprecate Old Version

**Workflow**: `.github/workflows/deprecate-version.yml`

```bash
# Deprecate v8 with 90-day notice
Actions → Deprecate API Version → Run workflow
  version: v8
  sunset_date: 2026-05-31
  migration_guide_url: https://...
```

Adds deprecation headers to responses:
```
X-API-Deprecated: true
X-API-Sunset-Date: 2026-05-31
Warning: 299 - "API version v8 is deprecated..."
```

#### 5. Sunset Version

**Workflow**: `.github/workflows/sunset-version.yml`

```bash
# Permanently remove v8
Actions → Sunset API Version → Run workflow
  version: v8
  confirm: CONFIRM
```

Removes API Gateway stage and Lambda aliases.

### Release Metadata Format

Each release contains JSON metadata in the body:

```json
{
  "version": "v10",
  "status": "planned",
  "sunsetDate": null,
  "migrationGuide": null,
  "lambdaAlias": "v10",
  "releaseDate": "2026-02-23T00:00:00Z",
  "lastDeployed": null,
  "previousVersion": "v9"
}
```

### CLI Commands

```bash
# List all API versions
gh release list --repo rgcleanslage/iqq-project | grep "api-"

# View version metadata
gh release view api-v10 --repo rgcleanslage/iqq-project

# Extract JSON metadata
gh release view api-v10 --repo rgcleanslage/iqq-project --json body --jq '.body' | \
  sed -n '/```json/,/```/p' | sed '1d;$d' | jq .

# Find current stable version
gh release list --repo rgcleanslage/iqq-project --json tagName,body --limit 100 | \
  jq -r '[.[] | select(.tagName | startswith("api-")) | 
    select(.body | contains("\"status\": \"stable\""))] | .[].tagName'
```

### Typical Version Creation Flow

```bash
# 1. Create v10 as planned
#    Actions → Add New API Version → v10, planned

# 2. Promote to alpha for internal testing
#    Actions → Update Version Status → v10, alpha

# 3. Deploy v10
#    Actions → Deploy API Version → v10

# 4. Test and promote to beta
#    Actions → Update Version Status → v10, beta

# 5. When ready, promote to stable
#    Actions → Update Version Status → v10, stable, make_current: true

# 6. Deprecate old version (v8)
#    Actions → Deprecate API Version → v8, sunset_date

# 7. After sunset date, remove v8
#    Actions → Sunset API Version → v8, CONFIRM
```

### Version Environment Variables

Services read version info from Lambda environment variables:

- `VERSION_STATUS`: stable, deprecated, etc.
- `VERSION_SUNSET_DATE`: ISO date or empty
- `VERSION_MIGRATION_GUIDE`: URL or empty
- `VERSION_CURRENT`: Current stable version

These are set during deployment and used by `response-builder.ts` to add appropriate headers.

## References

- #[[file:docs/deployment/DEPLOYMENT_GUIDE.md]]
- #[[file:docs/deployment/DEVELOPMENT_WORKFLOW.md]]
- #[[file:docs/deployment/API_VERSIONING_WITH_GITHUB_RELEASES.md]]
- #[[file:docs/deployment/CICD_SETUP_GUIDE.md]]
- #[[file:docs/deployment/GITHUB_OIDC_SETUP.md]]
- #[[file:docs/deployment/MANUAL_DEPLOYMENT_GUIDE.md]]
