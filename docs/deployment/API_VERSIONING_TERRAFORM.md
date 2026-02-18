# API Versioning Terraform Implementation

## Overview

This document details the Terraform changes implemented for stage-based API versioning. The implementation replaces environment-based stages (dev/prod) with version-based stages (v1/v2).

## Task 2: Update Terraform for Stage-Based Versioning ✅

**Status**: Complete  
**Date**: February 18, 2026  
**Files Modified**: 
- `iqq-infrastructure/modules/api-gateway/main.tf`
- `iqq-infrastructure/modules/api-gateway/outputs.tf`

## Changes Summary

### 1. API Gateway Stages

**Before** (Environment-based):
```terraform
# dev stage → Lambda v1 alias
resource "aws_api_gateway_stage" "dev" {
  stage_name = "dev"
  variables = {
    lambdaAlias = "v1"
  }
}

# prod stage → Lambda v2 alias
resource "aws_api_gateway_stage" "prod" {
  stage_name = "prod"
  variables = {
    lambdaAlias = "v2"
  }
}
```

**After** (Version-based):
```terraform
# v1 stage → Lambda v1 alias
resource "aws_api_gateway_stage" "v1" {
  stage_name = "v1"
  variables = {
    lambdaAlias = "v1"
  }
}

# v2 stage → Lambda v2 alias
resource "aws_api_gateway_stage" "v2" {
  stage_name = "v2"
  variables = {
    lambdaAlias = "v2"
  }
}
```

**Benefits**:
- ✅ Stage name directly represents API version
- ✅ Cleaner URLs: `/v1/package` instead of `/dev/package`
- ✅ No confusion between environment and version
- ✅ Easier to add new versions (just create new stage)

### 2. Lambda Permissions

**Before** (Single permission per service):
```terraform
resource "aws_lambda_permission" "package" {
  statement_id  = "AllowAPIGatewayInvoke"
  source_arn    = "${api.execution_arn}/*/*"
  qualifier     = "v1"
}
```

**After** (Separate permissions for each version):
```terraform
resource "aws_lambda_permission" "package_v1" {
  statement_id  = "AllowAPIGatewayInvokeV1"
  source_arn    = "${api.execution_arn}/v1/GET/package"
  qualifier     = "v1"
}

resource "aws_lambda_permission" "package_v2" {
  statement_id  = "AllowAPIGatewayInvokeV2"
  source_arn    = "${api.execution_arn}/v2/GET/package"
  qualifier     = "v2"
}
```

**Changes per service**:
- Package service: 2 permissions (v1, v2)
- Lender service: 2 permissions (v1, v2)
- Product service: 2 permissions (v1, v2)
- Document service: 2 permissions (v1, v2)
- **Total**: 8 Lambda permissions (was 4)

### 3. Usage Plans

**Before** (Single stage per plan):
```terraform
resource "aws_api_gateway_usage_plan" "standard" {
  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = "dev"
  }
}
```

**After** (Multiple stages per plan):
```terraform
resource "aws_api_gateway_usage_plan" "standard" {
  # Include both v1 and v2 stages
  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = "v1"
  }
  
  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = "v2"
  }
}
```

**Benefits**:
- ✅ Same API key works for both v1 and v2
- ✅ Unified rate limiting across versions
- ✅ Easier client migration (no new API keys needed)

### 4. CloudWatch Logging

**Enhanced log format** to include version information:
```terraform
access_log_settings {
  format = jsonencode({
    # ... existing fields ...
    stage          = "$context.stage"          # NEW: v1 or v2
    lambdaAlias    = "$stageVariables.lambdaAlias"  # NEW: v1 or v2
  })
}
```

### 5. Outputs

**Before**:
```terraform
output "dev_stage_url" {
  value = aws_api_gateway_stage.dev.invoke_url
}

output "prod_stage_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}
```

**After**:
```terraform
output "v1_stage_url" {
  value = aws_api_gateway_stage.v1.invoke_url
}

output "v2_stage_url" {
  value = aws_api_gateway_stage.v2.invoke_url
}
```

## URL Changes

### Before (Environment-based)
```
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/product
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/document
```

### After (Version-based)
```
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/lender
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/product
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/document

https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/package
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/lender
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/product
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/document
```

## Deployment Process

### Step 1: Test Terraform Plan

```bash
cd iqq-infrastructure
./scripts/test-versioning-plan.sh
```

This will:
- Validate Terraform configuration
- Generate a plan showing all changes
- Save plan to `versioning-plan.tfplan`

### Step 2: Review Expected Changes

The plan should show:
- **Destroy**: 2 resources (dev stage, prod stage)
- **Create**: 2 resources (v1 stage, v2 stage)
- **Update**: 8 resources (Lambda permissions)
- **Update**: 2 resources (Usage plans)
- **Update**: 2 resources (Outputs)

### Step 3: Apply Changes

```bash
cd iqq-infrastructure
terraform apply versioning-plan.tfplan
```

### Step 4: Verify Deployment

```bash
# Get new URLs
terraform output v1_stage_url
terraform output v2_stage_url

# Test v1 endpoint
curl -X GET "$(terraform output -raw v1_stage_url)/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# Test v2 endpoint
curl -X GET "$(terraform output -raw v2_stage_url)/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

## Impact Analysis

### Breaking Changes

⚠️ **URL Structure Changes**:
- Old URLs (`/dev/*`) will no longer work
- Clients must update to new URLs (`/v1/*` or `/v2/*`)

### Non-Breaking Changes

✅ **API Keys**: Existing API keys continue to work  
✅ **Authentication**: OAuth tokens continue to work  
✅ **Rate Limits**: Same rate limits apply  
✅ **Lambda Functions**: No changes needed (yet)

## Migration Checklist

- [ ] Review Terraform plan output
- [ ] Apply Terraform changes
- [ ] Verify both v1 and v2 stages are accessible
- [ ] Update Postman collections with new URLs
- [ ] Update documentation with new URLs
- [ ] Update test scripts with new URLs
- [ ] Notify clients of URL changes
- [ ] Update monitoring dashboards
- [ ] Update CI/CD pipelines

## Rollback Plan

If issues occur after deployment:

### Option 1: Revert Terraform Changes

```bash
cd iqq-infrastructure
git revert <commit-hash>
terraform apply
```

### Option 2: Manually Recreate Old Stages

```bash
# Create dev stage pointing to v1
aws apigateway create-stage \
  --rest-api-id r8ukhidr1m \
  --stage-name dev \
  --deployment-id <deployment-id> \
  --variables lambdaAlias=v1
```

## Testing

### Test v1 Stage

```bash
API_URL="https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1"

# Test package endpoint
curl -X GET "$API_URL/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# Test lender endpoint
curl -X GET "$API_URL/lender" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# Test product endpoint
curl -X GET "$API_URL/product" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# Test document endpoint
curl -X GET "$API_URL/document" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### Test v2 Stage

```bash
API_URL="https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2"

# Test all endpoints (same as v1)
# ...
```

### Verify Stage Variables

```bash
# Check v1 stage variables
aws apigateway get-stage \
  --rest-api-id r8ukhidr1m \
  --stage-name v1 \
  --query 'variables'

# Check v2 stage variables
aws apigateway get-stage \
  --rest-api-id r8ukhidr1m \
  --stage-name v2 \
  --query 'variables'
```

## Monitoring

### CloudWatch Logs

View logs with version information:

```bash
# View v1 logs
aws logs tail /aws/apigateway/iqq-dev --follow \
  --filter-pattern '{ $.stage = "v1" }'

# View v2 logs
aws logs tail /aws/apigateway/iqq-dev --follow \
  --filter-pattern '{ $.stage = "v2" }'
```

### CloudWatch Insights Queries

**Requests by version**:
```sql
fields @timestamp, stage, resourcePath, status
| stats count() by stage
```

**Error rate by version**:
```sql
fields @timestamp, stage, status
| filter status >= 400
| stats count() by stage
```

**Latency by version**:
```sql
fields @timestamp, stage, responseLength
| stats avg(responseLength) by stage
```

## Troubleshooting

### Issue: Lambda permission denied

**Symptom**: 403 Forbidden or "User is not authorized"

**Solution**: Verify Lambda permissions exist for both v1 and v2:
```bash
aws lambda get-policy \
  --function-name iqq-package-service-dev \
  --qualifier v1

aws lambda get-policy \
  --function-name iqq-package-service-dev \
  --qualifier v2
```

### Issue: Stage not found

**Symptom**: 404 Not Found

**Solution**: Verify stages exist:
```bash
aws apigateway get-stages \
  --rest-api-id r8ukhidr1m
```

### Issue: Usage plan not working

**Symptom**: Rate limit errors or API key not recognized

**Solution**: Verify usage plan includes both stages:
```bash
aws apigateway get-usage-plan \
  --usage-plan-id <plan-id>
```

## Next Steps

With Task 2 complete, proceed to:

1. **Task 3**: Implement Lambda version headers
   - Create response builder utility
   - Add version policy to each service
   - Update Lambda handlers

2. **Update Documentation**:
   - Update API documentation with new URLs
   - Update Postman collections
   - Update test scripts

3. **Notify Stakeholders**:
   - Inform clients of URL changes
   - Provide migration timeline
   - Share updated documentation

## References

- [API Versioning Requirements](../../.kiro/specs/api-versioning/requirements.md)
- [API Versioning Design](../../.kiro/specs/api-versioning/design.md)
- [API Versioning Tasks](../../.kiro/specs/api-versioning/tasks.md)
- [API Versioning Setup](../api/API_VERSIONING_SETUP.md)
- [AWS API Gateway Stages](https://docs.aws.amazon.com/apigateway/latest/developerguide/stages.html)

---

**Task Status**: ✅ Complete  
**Completed**: February 18, 2026  
**Next Task**: Task 3 - Implement Lambda version headers
