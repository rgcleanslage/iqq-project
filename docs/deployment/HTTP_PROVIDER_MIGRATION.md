# HTTP Provider Migration Guide

## Overview

This guide documents the migration from direct Lambda invocation (using Lambda ARNs) to HTTP-based invocation (using Lambda Function URLs) for provider services.

## Why HTTP Instead of Direct Lambda Invocation?

1. **Production-Ready Architecture**: HTTP invocation mirrors real-world scenarios where providers are external services accessed via HTTP/HTTPS
2. **Better Isolation**: Function URLs provide a clear API boundary between Step Functions and providers
3. **Easier Testing**: HTTP endpoints can be tested with standard HTTP tools (curl, Postman, SoapUI)
4. **Flexibility**: Easier to swap Lambda implementations with external HTTP services in the future
5. **Monitoring**: HTTP-level metrics and logging for better observability

## Architecture Changes

### Before (Lambda ARN Invocation)
```
Step Functions → Lambda Invoke (arn:aws:lambda:...) → Provider Lambda
```

### After (HTTP URL Invocation)
```
Step Functions → HTTP POST (https://...lambda-url.on.aws/) → Provider Lambda
```

## Changes Made

### 1. Lambda Function URLs Added

**File**: `iqq-providers/template.yaml`

Added Lambda Function URLs for each provider:
- `ClientProviderUrl` - Client Insurance provider
- `Route66ProviderUrl` - Route 66 Insurance provider  
- `APCOProviderUrl` - APCO Insurance provider

Each Function URL includes:
- `AuthType: NONE` - No authentication (internal use only)
- Permission for public invocation via Function URL
- CloudFormation output for easy reference

### 2. DynamoDB Schema Updated

**File**: `scripts/seed-dynamodb.ts`

Provider records now include:
- `providerUrl` - Lambda Function URL (primary field for invocation)
- `lambdaArn` - Lambda ARN (kept for backward compatibility)

Example:
```typescript
{
  providerId: 'PROV-CLIENT',
  providerName: 'Client Insurance',
  providerUrl: 'https://abc123.lambda-url.us-east-1.on.aws/',
  lambdaArn: 'arn:aws:lambda:us-east-1:123456789:function:iqq-provider-client-dev',
  responseFormat: 'CSV',
  // ...
}
```

### 3. Provider Loader Updated

**File**: `iqq-providers/provider-loader/src/index.ts`

Changed to return `providerUrl` instead of `lambdaArn`:
```typescript
const providerList = providers.map(provider => ({
  providerId: provider.providerId,
  providerName: provider.providerName,
  providerUrl: provider.providerUrl,  // Changed from lambdaArn
  responseFormat: provider.responseFormat,
  // ...
}));
```

### 4. Step Functions State Machine Updated

**File**: `iqq-infrastructure/modules/step-functions/state-machine-dynamic.json`

Changed from Lambda invoke to HTTP invoke:

**Before**:
```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::lambda:invoke",
  "Parameters": {
    "FunctionName.$": "$.lambdaArn",
    "Payload": { ... }
  }
}
```

**After**:
```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::http:invoke",
  "Parameters": {
    "ApiEndpoint.$": "$.providerUrl",
    "Method": "POST",
    "RequestBody": { ... },
    "Authentication": {
      "ConnectionArn": "NONE"
    }
  }
}
```

Response structure also changed:
- Lambda: `$.providerResponse.Payload.body`
- HTTP: `$.providerResponse.ResponseBody.body`

### 5. URL Update Script Created

**File**: `scripts/update-provider-urls.ts`

Automated script to:
1. Fetch Lambda Function URLs from CloudFormation outputs
2. Update DynamoDB provider records with actual URLs
3. Run after each deployment to sync URLs

## Deployment Steps

### Step 1: Deploy Provider Lambdas with Function URLs

```bash
cd iqq-providers

# Build all functions
npm run build

# Deploy with SAM
sam build
sam deploy --config-env dev
```

This creates Lambda Function URLs and outputs them in CloudFormation.

### Step 2: Update DynamoDB with Function URLs

```bash
# Extract URLs from CloudFormation and update DynamoDB
TABLE_NAME=iqq-config-dev STACK_NAME=iqq-providers-dev ts-node scripts/update-provider-urls.ts
```

Or manually update the URLs in `scripts/seed-dynamodb.ts` and re-run:
```bash
TABLE_NAME=iqq-config-dev ts-node scripts/seed-dynamodb.ts
```

### Step 3: Deploy Infrastructure with Updated State Machine

```bash
cd iqq-infrastructure

# Initialize and apply Terraform changes
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

This deploys the updated Step Functions state machine with HTTP invoke.

### Step 4: Test the Integration

```bash
# Test via API Gateway
curl -X POST https://your-api-gateway-url/quotes \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -d '{
    "productCode": "MBP",
    "coverageType": "COMPREHENSIVE",
    "vehicleValue": 25000,
    "term": 36
  }'
```

Or test Step Functions directly:
```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789:stateMachine:iqq-quote-orchestration-dev \
  --input '{
    "productCode": "MBP",
    "coverageType": "COMPREHENSIVE",
    "vehicleValue": 25000,
    "term": 36
  }'
```

## Testing Individual Provider URLs

You can test each provider Function URL directly:

```bash
# Test Client Provider (CSV)
curl -X POST https://your-client-url.lambda-url.us-east-1.on.aws/ \
  -H "Content-Type: application/json" \
  -d '{
    "requestContext": {
      "requestId": "test-123"
    },
    "queryStringParameters": {
      "productCode": "MBP",
      "coverageType": "COMPREHENSIVE",
      "vehicleValue": "25000",
      "term": "36"
    }
  }'

# Test Route 66 Provider (JSON)
curl -X POST https://your-route66-url.lambda-url.us-east-1.on.aws/ \
  -H "Content-Type: application/json" \
  -d '{
    "requestContext": {
      "requestId": "test-456"
    },
    "queryStringParameters": {
      "productCode": "MBP",
      "coverageType": "COMPREHENSIVE",
      "vehicleValue": "25000",
      "term": "36"
    }
  }'

# Test APCO Provider (XML)
curl -X POST https://your-apco-url.lambda-url.us-east-1.on.aws/ \
  -H "Content-Type: application/json" \
  -d '{
    "requestContext": {
      "requestId": "test-789"
    },
    "queryStringParameters": {
      "productCode": "MBP",
      "coverageType": "COMPREHENSIVE",
      "vehicleValue": "25000",
      "term": "36"
    }
  }'
```

## Monitoring and Debugging

### CloudWatch Logs

Each provider Lambda has its own log group:
- `/aws/lambda/iqq-provider-client-dev`
- `/aws/lambda/iqq-provider-route66-dev`
- `/aws/lambda/iqq-provider-apco-dev`

### Step Functions Execution History

View HTTP request/response in Step Functions console:
1. Go to Step Functions → State Machines
2. Select `iqq-quote-orchestration-dev`
3. View execution details
4. Inspect "InvokeProvider" step to see HTTP request/response

### Common Issues

**Issue**: Step Functions shows "States.Http.StatusCodeError"
- **Cause**: Provider Lambda returned non-200 status code
- **Fix**: Check provider Lambda logs for errors

**Issue**: "ApiEndpoint parameter is invalid"
- **Cause**: `providerUrl` is not set or invalid in DynamoDB
- **Fix**: Run `update-provider-urls.ts` script or manually update DynamoDB

**Issue**: HTTP timeout
- **Cause**: Provider Lambda taking too long to respond
- **Fix**: Increase timeout in Step Functions state machine or optimize Lambda

## Security Considerations

### Current Setup (Development)
- Function URLs have `AuthType: NONE`
- No authentication required
- Suitable for internal Step Functions invocation

### Production Recommendations
1. **Use AWS IAM Authentication**:
   ```yaml
   AuthType: AWS_IAM
   ```
   
2. **Add EventBridge Connection** for Step Functions:
   ```json
   "Authentication": {
     "ConnectionArn": "arn:aws:events:us-east-1:123456789:connection/..."
   }
   ```

3. **Restrict Function URL Access**:
   - Use resource policies to allow only Step Functions
   - Add VPC configuration for private access

4. **Add Request Validation**:
   - Validate request signature
   - Check correlation IDs
   - Rate limiting

## Rollback Plan

If issues occur, you can rollback to Lambda ARN invocation:

1. Revert `state-machine-dynamic.json` to use `lambda:invoke`
2. Update Provider Loader to return `lambdaArn`
3. Redeploy infrastructure

The `lambdaArn` field is still stored in DynamoDB for backward compatibility.

## Performance Comparison

### Lambda Invoke (Before)
- Latency: ~10-20ms
- Direct invocation
- No HTTP overhead

### HTTP Invoke (After)
- Latency: ~20-50ms
- HTTP request/response overhead
- More realistic production scenario

The slight latency increase is acceptable for the benefits of HTTP-based architecture.

## Next Steps

1. Monitor HTTP invocation performance in production
2. Add authentication to Function URLs
3. Implement request/response logging
4. Add circuit breaker pattern for provider failures
5. Consider API Gateway in front of providers for additional features

## References

- [AWS Lambda Function URLs](https://docs.aws.amazon.com/lambda/latest/dg/lambda-urls.html)
- [Step Functions HTTP Integration](https://docs.aws.amazon.com/step-functions/latest/dg/connect-third-party-apis.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
