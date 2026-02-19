# V5 API Deployment Fixes

**Date**: February 19, 2026  
**Status**: Complete

## Issues Identified

During the v5 API deployment and testing, we discovered three critical issues that prevented the API from working:

### 1. Missing Usage Plan Configuration
**Problem**: The v5 stage was not added to any API Gateway usage plans, causing 403 Forbidden errors even with valid API keys.

**Root Cause**: Usage plans were manually configured to only include v1 and v2 stages.

**Solution**: Updated both `add-new-version.yml` and `deploy-version.yml` workflows to automatically add new versions to all existing usage plans.

### 2. Missing Lambda Resource Policies
**Problem**: Lambda aliases didn't have resource policies allowing API Gateway to invoke them, resulting in 403 errors.

**Root Cause**: The `add-new-version` workflow was adding permissions to the base function instead of the alias, and using incorrect source ARN patterns.

**Solution**: 
- Fixed permission statements to target the alias (`function-name:version`)
- Updated source ARN to use wildcard pattern: `arn:aws:execute-api:region:account:api-id/version/*/*`
- Added permission updates to the `deploy-version` workflow as well

### 3. Incorrect Cognito Client ID Mapping
**Problem**: The package service was mapping the test Cognito client ID to `LEGACY` instead of `CLI001`, causing client ID mismatch errors.

**Root Cause**: Outdated mapping in `iqq-package-service/src/index.ts`.

**Solution**: Updated the mapping to map `YOUR_CLIENT_ID` to `CLI001`.

## Changes Made

### Workflow Updates

#### `.github/workflows/add-new-version.yml`
- Updated `Add Lambda permissions` step to:
  - Target Lambda aliases correctly (`function-name:version`)
  - Use proper source ARN pattern with wildcards
  - Use consistent statement ID format: `apigateway-{version}-invoke`
- Added new `Update usage plans` step to:
  - Automatically add new version to all existing usage plans
  - Check if version already exists before adding
  - Handle errors gracefully

#### `.github/workflows/deploy-version.yml`
- Added `Get API Gateway ID` step
- Added `Update Lambda permissions` step to ensure permissions are set during deployment
- Added `Update usage plans` step to ensure usage plans include the version
- Moved API Gateway redeployment to final step

### Service Updates

#### `iqq-package-service/src/index.ts`
```typescript
// Before
'YOUR_CLIENT_ID': 'LEGACY' // Legacy client

// After
'YOUR_CLIENT_ID': 'CLI001' // Current test client
```

## Testing Results

After applying all fixes, all v5 endpoints were tested successfully:

```bash
# Package Service
GET /v5/package
✅ HTTP 200 - Returns package with 2 provider quotes

# Lender Service  
GET /v5/lender
✅ HTTP 200 - Returns lender information

# Product Service
GET /v5/product
✅ HTTP 200 - Returns product information

# Document Service
GET /v5/document
✅ HTTP 200 - Returns document information
```

## Manual Fixes Applied

For the v5 deployment, the following manual fixes were applied:

1. **Usage Plans**: Added v5 to both premium and standard usage plans
   ```bash
   aws apigateway update-usage-plan --usage-plan-id b1fzzv \
     --patch-operations op=add,path=/apiStages,value=r8ukhidr1m:v5
   
   aws apigateway update-usage-plan --usage-plan-id o9rmvs \
     --patch-operations op=add,path=/apiStages,value=r8ukhidr1m:v5
   ```

2. **Lambda Permissions**: Added resource policies for all 4 service aliases
   ```bash
   for SERVICE in package lender product document; do
     aws lambda add-permission \
       --function-name iqq-${SERVICE}-service-dev:v5 \
       --statement-id apigateway-v5-invoke \
       --action lambda:InvokeFunction \
       --principal apigateway.amazonaws.com \
       --source-arn "arn:aws:execute-api:us-east-1:785826687678:r8ukhidr1m/v5/*/*"
   done
   ```

3. **Package Service**: Updated and redeployed with corrected client ID mapping

## Future Deployments

With the workflow updates in place, future API version deployments will automatically:
- Create Lambda resource policies for API Gateway invocation
- Add new versions to all existing usage plans
- Handle permissions correctly for Lambda aliases

No manual intervention should be required for these issues going forward.

## Related Documentation

- [API Versioning with GitHub Releases](./API_VERSIONING_WITH_GITHUB_RELEASES.md)
- [Add New Version Workflow Guide](./ADD_NEW_VERSION_WORKFLOW_GUIDE.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
