# Migration from Custom Lambda Authorizer to Cognito Authorizer

## Overview

This document describes the migration from a custom Lambda authorizer to AWS API Gateway's native Cognito authorizer with built-in API key support.

## Why Migrate?

### Problems with Custom Lambda Authorizer:
1. **Unnecessary complexity** - Custom code to validate JWT tokens that Cognito can do natively
2. **Higher latency** - Lambda cold starts add 100-500ms to every request
3. **Higher costs** - Pay for Lambda invocations on every API call
4. **Maintenance burden** - Need to maintain authorizer code, tests, and deployments
5. **Duplicate functionality** - API Gateway already has native API key support

### Benefits of Cognito Authorizer:
1. **Zero latency** - No Lambda invocation, validation happens in API Gateway
2. **Lower cost** - No Lambda charges for authorization
3. **Less code** - Remove entire authorizer Lambda function
4. **Native features** - Use API Gateway's built-in API key management, usage plans, and throttling
5. **Better caching** - 5-minute authorization cache (vs 0 seconds with custom authorizer)

## What Changed

### Before:
```
Client Request
    ↓
API Gateway
    ↓
Custom Lambda Authorizer (validates OAuth + API key from DynamoDB)
    ↓
Backend Lambda
```

### After:
```
Client Request
    ↓
API Gateway (validates OAuth via Cognito + API key natively)
    ↓
Backend Lambda
```

## Infrastructure Changes

### 1. API Gateway Authorizer

**Before:**
```terraform
resource "aws_api_gateway_authorizer" "lambda" {
  name                   = "lambda-authorizer"
  type                   = "REQUEST"
  authorizer_uri         = "arn:aws:apigateway:...:function:iqq-authorizer-dev/invocations"
  identity_source        = "method.request.header.Authorization,method.request.header.x-api-key"
  authorizer_result_ttl_in_seconds = 0  # No caching
}
```

**After:**
```terraform
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito-authorizer"
  type          = "COGNITO_USER_POOLS"
  provider_arns = [var.cognito_user_pool_arn]
  authorizer_result_ttl_in_seconds = 300  # 5-minute cache
}
```

### 2. API Methods

**Before:**
```terraform
resource "aws_api_gateway_method" "lender_get" {
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda.id
  api_key_required = false  # Handled by custom authorizer
}
```

**After:**
```terraform
resource "aws_api_gateway_method" "lender_get" {
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
  api_key_required = true  # Native API Gateway validation
}
```

### 3. API Keys

API keys are now managed by API Gateway instead of DynamoDB:

```terraform
# API Key
resource "aws_api_gateway_api_key" "default" {
  name    = "iqq-default-key-dev"
  enabled = true
}

# Usage Plan (rate limiting + quotas)
resource "aws_api_gateway_usage_plan" "standard" {
  name = "iqq-standard-plan-dev"
  
  quota_settings {
    limit  = 10000  # 10K requests/month
    period = "MONTH"
  }
  
  throttle_settings {
    burst_limit = 100  # Max concurrent
    rate_limit  = 50   # Requests/second
  }
}

# Associate key with plan
resource "aws_api_gateway_usage_plan_key" "default_standard" {
  key_id        = aws_api_gateway_api_key.default.id
  usage_plan_id = aws_api_gateway_usage_plan.standard.id
}
```

## Deployment Steps

### 1. Apply Terraform Changes

```bash
cd iqq-infrastructure
terraform init
terraform plan
terraform apply
```

This will:
- Create Cognito authorizer
- Update all API methods to use Cognito authorizer
- Enable native API key validation
- Remove custom Lambda authorizer references

### 2. Get API Gateway API Keys

```bash
# Get the default API key value
aws apigateway get-api-key \
  --api-key $(aws apigateway get-api-keys --query 'items[?name==`iqq-default-key-dev`].id' --output text) \
  --include-value \
  --query 'value' \
  --output text
```

Save this key - you'll need it for API requests.

### 3. Test API with New Authentication

```bash
# Get OAuth token from Cognito
TOKEN=$(curl -X POST https://iqq-auth.auth.us-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET" \
  | jq -r '.access_token')

# Get API key from API Gateway
API_KEY=$(aws apigateway get-api-key \
  --api-key $(aws apigateway get-api-keys --query 'items[?name==`iqq-default-key-dev`].id' --output text) \
  --include-value \
  --query 'value' \
  --output text)

# Test API
curl -X GET https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/products \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### 4. (Optional) Remove Custom Authorizer Lambda

Once confirmed working, you can remove the authorizer Lambda:

```bash
cd iqq-providers
# Remove authorizer directory
rm -rf authorizer/

# Update template.yaml to remove AuthorizerFunction resource

# Commit and deploy
git add -A
git commit -m "Remove custom authorizer Lambda (replaced with Cognito authorizer)"
git push origin main
```

## API Key Management

### Creating New API Keys

```bash
# Create API key
aws apigateway create-api-key \
  --name "partner-x-key-dev" \
  --description "API key for Partner X" \
  --enabled

# Get the key ID
KEY_ID=$(aws apigateway get-api-keys --query 'items[?name==`partner-x-key-dev`].id' --output text)

# Associate with usage plan
aws apigateway create-usage-plan-key \
  --usage-plan-id <usage-plan-id> \
  --key-id $KEY_ID \
  --key-type API_KEY
```

### Revoking API Keys

```bash
# Disable key
aws apigateway update-api-key \
  --api-key <key-id> \
  --patch-operations op=replace,path=/enabled,value=false

# Or delete permanently
aws apigateway delete-api-key --api-key <key-id>
```

### Viewing Usage

```bash
# Get usage statistics
aws apigateway get-usage \
  --usage-plan-id <usage-plan-id> \
  --start-date 2024-01-01 \
  --end-date 2024-01-31
```

## Monitoring

### CloudWatch Metrics

API Gateway now provides built-in metrics:
- `Count` - Total API requests
- `4XXError` - Client errors (including auth failures)
- `5XXError` - Server errors
- `Latency` - Request latency
- `IntegrationLatency` - Backend latency

### Authorization Failures

Check CloudWatch Logs for authorization errors:
```bash
aws logs filter-log-events \
  --log-group-name /aws/apigateway/iqq-dev \
  --filter-pattern "Unauthorized"
```

## Troubleshooting

### 401 Unauthorized - Missing API key

Error: `{"message":"Forbidden"}`

Solution: Include `x-api-key` header in request

### 401 Unauthorized - Invalid token

Error: `{"message":"Unauthorized"}`

Causes:
- Token expired (Cognito tokens expire after 1 hour)
- Token from wrong user pool
- Token is ID token instead of access token

Solution: Get fresh access token from Cognito

### 403 Forbidden - Usage limit exceeded

Error: `{"message":"Limit Exceeded"}`

Cause: API key has exceeded usage plan quota or throttle limit

Solution: Wait for quota reset or upgrade to higher usage plan

## Cost Comparison

### Before (Custom Lambda Authorizer):
- Lambda invocations: $0.20 per 1M requests
- Lambda duration: $0.0000166667 per GB-second
- Estimated: ~$5-10/month for 1M requests

### After (Cognito Authorizer):
- API Gateway requests: $3.50 per 1M requests (same as before)
- Cognito: Free for first 50K MAU
- No additional Lambda costs
- Estimated: ~$0/month additional (included in API Gateway)

**Savings: ~$5-10/month per 1M requests**

## Migration Checklist

- [x] Update Terraform to use Cognito authorizer
- [x] Remove custom Lambda authorizer references
- [x] Enable native API key validation
- [x] Deploy infrastructure changes
- [ ] Get API Gateway API keys
- [ ] Test API with new authentication
- [ ] Update client applications with new API keys
- [ ] Monitor for authorization errors
- [ ] (Optional) Remove custom authorizer Lambda code
- [ ] Update documentation

## Rollback Plan

If issues occur, rollback is simple:

```bash
cd iqq-infrastructure
git revert HEAD
git push origin main
terraform apply
```

This will restore the custom Lambda authorizer.

## Files Changed

- `iqq-infrastructure/modules/api-gateway/main.tf` - Replaced Lambda authorizer with Cognito
- `iqq-infrastructure/modules/api-gateway/variables.tf` - Removed authorizer_function_name
- `iqq-infrastructure/main.tf` - Removed authorizer_function_name parameter
- `iqq-infrastructure/variables.tf` - Removed authorizer and api_key_required variables

## Next Steps

1. Deploy Terraform changes
2. Get API Gateway API keys
3. Test thoroughly
4. Update client applications
5. Remove custom authorizer Lambda (optional)
6. Update API documentation with new authentication flow
