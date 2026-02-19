# Task 6: Deploy Initial Versions - Instructions

**Date**: February 18, 2026  
**Status**: Ready to Execute

## Overview

Task 6 involves deploying Lambda functions to v1 and v2 aliases. The service deployment workflows are now in place in all 4 service repositories.

## Prerequisites Completed

✅ Release branches created (Task 5)
- release/v1 and release/v2 exist in all repositories

✅ Service deployment workflows deployed
- `.github/workflows/deploy.yml` added to all 4 services
- Workflows pushed to GitHub

✅ Terraform infrastructure ready (Task 2)
- v1 and v2 API Gateway stages exist
- Lambda permissions configured

✅ Version headers implemented (Task 3)
- All services have response-builder utility
- Version policy configuration in place

## Required Secrets

Before deploying, ensure these secrets are configured in GitHub:

### Root Repository (iqq-project)
- `PAT_TOKEN` - GitHub Personal Access Token with `repo` and `workflow` scopes
- `AWS_ROLE_ARN` - Already set: `arn:aws:iam::785826687678:role/github-actions-sam-dev`

### Service Repositories (all 4)
- `AWS_ROLE_ARN` - Already set: `arn:aws:iam::785826687678:role/github-actions-sam-dev`
- `SAM_DEPLOYMENT_BUCKET` - Already set: `iqq-sam-deployments-785826687678`

## Deployment Options

You have two options for deploying:

### Option 1: Centralized Deployment (Recommended)

Use the root repository's "Deploy API Version" workflow to deploy all services at once.

**Steps:**

1. Go to: https://github.com/rgcleanslage/iqq-project/actions
2. Click "Deploy API Version"
3. Click "Run workflow"
4. For v1 deployment:
   - **version**: `v1`
   - **services**: `all`
   - **environment**: `dev`
5. Click "Run workflow"
6. Wait for completion (~10-15 minutes)
7. Repeat for v2:
   - **version**: `v2`
   - **services**: `all`
   - **environment**: `dev`

**What This Does:**
- Triggers deployment in all 4 service repositories
- Builds and tests each service
- Deploys Lambda functions via SAM
- Creates/updates Lambda aliases (v1 or v2)
- Verifies deployments
- Updates version policy

### Option 2: Individual Service Deployment

Deploy each service individually using their own workflows.

**Steps for Each Service:**

1. **Package Service**
   - Go to: https://github.com/rgcleanslage/iqq-package-service/actions
   - Click "Deploy Service"
   - Run workflow with version: `v1`, environment: `dev`
   - Repeat for `v2`

2. **Lender Service**
   - Go to: https://github.com/rgcleanslage/iqq-lender-service/actions
   - Click "Deploy Service"
   - Run workflow with version: `v1`, environment: `dev`
   - Repeat for `v2`

3. **Product Service**
   - Go to: https://github.com/rgcleanslage/iqq-product-service/actions
   - Click "Deploy Service"
   - Run workflow with version: `v1`, environment: `dev`
   - Repeat for `v2`

4. **Document Service**
   - Go to: https://github.com/rgcleanslage/iqq-document-service/actions
   - Click "Deploy Service"
   - Run workflow with version: `v1`, environment: `dev`
   - Repeat for `v2`

## Deployment Process

Each deployment will:

1. **Validate** - Check version exists in version policy
2. **Test** - Run unit tests and linting
3. **Build** - Compile TypeScript and build SAM application
4. **Deploy** - Deploy Lambda function via SAM
5. **Update Alias** - Create/update Lambda alias (v1 or v2)
6. **Verify** - Test Lambda function invocation

## Expected Results

After successful deployment:

### Lambda Functions
- `iqq-package-service-dev` with aliases: v1, v2
- `iqq-lender-service-dev` with aliases: v1, v2
- `iqq-product-service-dev` with aliases: v1, v2
- `iqq-document-service-dev` with aliases: v1, v2

### API Gateway
- v1 stage routes to Lambda alias v1
- v2 stage routes to Lambda alias v2

### Endpoints Available
- `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package`
- `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/lender`
- `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/product`
- `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/document`
- `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/package`
- `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/lender`
- `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/product`
- `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/document`

## Verification Commands

After deployment, verify Lambda aliases:

```bash
# Check package service aliases
aws lambda list-aliases \
  --function-name iqq-package-service-dev \
  --region us-east-1

# Check lender service aliases
aws lambda list-aliases \
  --function-name iqq-lender-service-dev \
  --region us-east-1

# Check product service aliases
aws lambda list-aliases \
  --function-name iqq-product-service-dev \
  --region us-east-1

# Check document service aliases
aws lambda list-aliases \
  --function-name iqq-document-service-dev \
  --region us-east-1
```

Expected output for each:
```json
{
    "Aliases": [
        {
            "AliasArn": "arn:aws:lambda:us-east-1:785826687678:function:iqq-package-service-dev:v1",
            "Name": "v1",
            "FunctionVersion": "1",
            "Description": "Created by GitHub Actions"
        },
        {
            "AliasArn": "arn:aws:lambda:us-east-1:785826687678:function:iqq-package-service-dev:v2",
            "Name": "v2",
            "FunctionVersion": "2",
            "Description": "Created by GitHub Actions"
        }
    ]
}
```

## Troubleshooting

### Workflow Fails at Test Step
- Check test failures in workflow logs
- Fix tests and re-run deployment

### Workflow Fails at Deploy Step
- Verify AWS credentials are configured
- Check SAM_DEPLOYMENT_BUCKET exists
- Verify AWS_ROLE_ARN has correct permissions

### Alias Creation Fails
- Check Lambda function exists
- Verify function version was published
- Check IAM permissions for alias operations

### Deployment Timeout
- Increase timeout in workflow if needed
- Check AWS service health
- Verify network connectivity

## Manual Deployment (Alternative)

If GitHub Actions are not available, deploy manually:

```bash
# For each service
cd iqq-package-service

# Build
npm ci
npm run build
sam build

# Deploy
sam deploy \
  --stack-name iqq-package-service-dev \
  --s3-bucket iqq-sam-deployments-785826687678 \
  --s3-prefix iqq-package-service \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides "Environment=dev" \
  --region us-east-1

# Create v1 alias
aws lambda publish-version \
  --function-name iqq-package-service-dev \
  --description "v1 release"

aws lambda create-alias \
  --function-name iqq-package-service-dev \
  --name v1 \
  --function-version 1

# Create v2 alias
aws lambda publish-version \
  --function-name iqq-package-service-dev \
  --description "v2 release"

aws lambda create-alias \
  --function-name iqq-package-service-dev \
  --name v2 \
  --function-version 2
```

## Next Steps

After successful deployment:

1. **Proceed to Task 7**: Verify versioned endpoints
   - Test all v1 endpoints
   - Test all v2 endpoints
   - Verify version headers
   - Test concurrent access

2. **Update Documentation**
   - Document deployment results
   - Update API reference with version info

## Important Notes

- **PAT_TOKEN Required**: The centralized deployment workflow requires PAT_TOKEN to trigger service workflows
- **First Deployment**: Initial deployment may take longer (~15-20 minutes per service)
- **Subsequent Deployments**: Faster (~5-10 minutes per service)
- **Parallel Deployment**: Centralized workflow deploys all services in parallel
- **Version Isolation**: v1 and v2 are completely independent

## Support

For issues:
- Check workflow logs in GitHub Actions
- Review CloudWatch logs for Lambda functions
- Verify AWS credentials and permissions
- Check API Gateway stage configuration

---

**Created**: February 18, 2026  
**Ready for Execution**: Yes  
**Estimated Time**: 30-40 minutes (all services, both versions)
