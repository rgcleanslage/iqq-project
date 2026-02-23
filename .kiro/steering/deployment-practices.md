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

## References

- #[[file:docs/deployment/DEPLOYMENT_GUIDE.md]]
- #[[file:docs/deployment/DEVELOPMENT_WORKFLOW.md]]
- #[[file:docs/deployment/CICD_SETUP_GUIDE.md]]
- #[[file:docs/deployment/GITHUB_OIDC_SETUP.md]]
- #[[file:docs/deployment/MANUAL_DEPLOYMENT_GUIDE.md]]
