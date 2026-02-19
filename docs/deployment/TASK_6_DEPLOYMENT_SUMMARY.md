# Task 6: Deploy Initial Versions - Summary

## Overview

This document summarizes the deployment of v1 and v2 Lambda versions with API Gateway integration.

## Issues Encountered and Resolved

### Issue 1: Lambda Permissions Conflict

**Problem**: Lambda resource-based policies were managed by Terraform but were being removed when SAM redeployed the Lambda functions.

**Root Cause**: SAM and Terraform were both trying to manage Lambda resources, causing conflicts.

**Solution**: 
- Added Lambda aliases (v1, v2, latest) to SAM templates so they're deployed with the functions
- Keep Lambda permissions managed by Terraform (they reference API Gateway)
- This ensures aliases persist across SAM deployments

**Files Modified**:
- `iqq-package-service/template.yaml`
- `iqq-lender-service/template.yaml`
- `iqq-product-service/template.yaml`
- `iqq-document-service/template.yaml`

### Issue 2: Missing Makefiles

**Problem**: SAM build was failing because Makefiles weren't committed to the service repositories.

**Root Cause**: Makefiles were in `.gitignore` or simply not tracked.

**Solution**: 
- Added and committed Makefiles to all 4 service repositories
- Makefiles handle TypeScript compilation and dependency installation

**Files Added**:
- `iqq-package-service/Makefile`
- `iqq-lender-service/Makefile`
- `iqq-product-service/Makefile`
- `iqq-document-service/Makefile`

## SAM Template Changes

Added Lambda aliases to each service template:

```yaml
# Lambda Aliases for API versioning
PackageFunctionAliasV1:
  Type: AWS::Lambda::Alias
  Properties:
    FunctionName: !Ref PackageFunction
    FunctionVersion: $LATEST
    Name: v1

PackageFunctionAliasV2:
  Type: AWS::Lambda::Alias
  Properties:
    FunctionName: !Ref PackageFunction
    FunctionVersion: $LATEST
    Name: v2

PackageFunctionAliasLatest:
  Type: AWS::Lambda::Alias
  Properties:
    FunctionName: !Ref PackageFunction
    FunctionVersion: $LATEST
    Name: latest
```

## Deployment Architecture

### Lambda Aliases
- **v1**: Points to Lambda version 1 (stable)
- **v2**: Points to $LATEST (development)
- **latest**: Points to $LATEST (for testing)

### API Gateway Stages
- **v1 stage**: Uses stage variable `lambdaAlias=v1`
- **v2 stage**: Uses stage variable `lambdaAlias=v2`

### Integration Flow
```
API Gateway Stage (v1) 
  → Stage Variable (lambdaAlias=v1)
  → Lambda Integration URI (uses ${stageVariables.lambdaAlias})
  → Lambda Function:v1 alias
  → Lambda Version 1
```

## Deployment Process

### Step 1: Update SAM Templates
1. Added Lambda alias resources to all service templates
2. Committed and pushed changes to service repositories

### Step 2: Commit Makefiles
1. Added Makefiles to all service repositories
2. Committed and pushed changes

### Step 3: Trigger Deployments
1. Used `scripts/trigger-deployments.sh` to deploy both v1 and v2
2. Deployments run in parallel (max 2 at a time)
3. Each service deployment:
   - Validates configuration
   - Runs tests
   - Builds with SAM
   - Deploys to AWS
   - Updates Lambda aliases
   - Verifies deployment

### Step 4: Apply Terraform Permissions
After SAM deployments complete, Terraform must reapply Lambda permissions:

```bash
cd iqq-infrastructure
terraform apply -auto-approve \
  -target=module.api_gateway.aws_lambda_permission.package_v1 \
  -target=module.api_gateway.aws_lambda_permission.package_v2 \
  -target=module.api_gateway.aws_lambda_permission.lender_v1 \
  -target=module.api_gateway.aws_lambda_permission.lender_v2 \
  -target=module.api_gateway.aws_lambda_permission.product_v1 \
  -target=module.api_gateway.aws_lambda_permission.product_v2 \
  -target=module.api_gateway.aws_lambda_permission.document_v1 \
  -target=module.api_gateway.aws_lambda_permission.document_v2
```

### Step 5: Redeploy API Gateway
After permissions are applied, redeploy API Gateway stages:

```bash
aws apigateway create-deployment \
  --rest-api-id r8ukhidr1m \
  --region us-east-1 \
  --stage-name v1 \
  --description "Redeploy after Lambda permissions update"

aws apigateway create-deployment \
  --rest-api-id r8ukhidr1m \
  --region us-east-1 \
  --stage-name v2 \
  --description "Redeploy after Lambda permissions update"
```

## Current Status

### Deployments
- ✅ SAM templates updated with Lambda aliases
- ✅ Makefiles committed to all services
- 🔄 GitHub Actions workflows running (v1 and v2 deployments)
- ⏳ Waiting for deployments to complete

### Next Steps
1. Wait for GitHub Actions workflows to complete (~5-10 minutes)
2. Verify Lambda aliases are created correctly
3. Apply Terraform Lambda permissions
4. Redeploy API Gateway stages
5. Test endpoints with `scripts/test-api-versioning.sh`

## Verification Commands

### Check Deployment Status
```bash
cd scripts
bash check-deployment-status.sh
```

### Check Lambda Aliases
```bash
for service in package lender product document; do
  echo "=== iqq-${service}-service-dev ==="
  aws lambda list-aliases \
    --region us-east-1 \
    --function-name "iqq-${service}-service-dev" \
    --query 'Aliases[*].[Name,FunctionVersion]' \
    --output table
done
```

### Test Endpoints
```bash
bash scripts/test-api-versioning.sh
```

## Lessons Learned

1. **SAM and Terraform Integration**: When using both tools, clearly define ownership:
   - SAM manages: Lambda functions, aliases, log groups
   - Terraform manages: API Gateway, permissions, stages

2. **Lambda Aliases**: Must be created by SAM (not Terraform) to persist across deployments

3. **Build Dependencies**: Ensure all build files (Makefiles, package.json, etc.) are committed

4. **Deployment Order**: 
   - Deploy Lambda functions first (SAM)
   - Then apply permissions (Terraform)
   - Finally redeploy API Gateway

## Related Documentation

- [API Versioning Setup](../api/API_VERSIONING_SETUP.md)
- [GitHub Actions Versioning](GITHUB_ACTIONS_VERSIONING.md)
- [Task 6 Instructions](TASK_6_INSTRUCTIONS.md)
- [API Version Headers](../api/API_VERSION_HEADERS.md)
