# Path-Based Access Control Guide

## Overview

This guide explains how to implement path-based access control in your API Gateway using the Lambda authorizer, allowing you to restrict which endpoints different applications (client_ids) can access.

## How It Works

The Lambda authorizer:
1. Validates the JWT token from Cognito
2. Extracts the `client_id` from the token
3. Looks up the allowed paths for that client in the `CLIENT_ACCESS_RULES` configuration
4. Returns an IAM policy that only allows access to those specific paths

## Configuration

### Step 1: Define Access Rules

Edit `iqq-authorizer-service/src/index.ts` and update the `CLIENT_ACCESS_RULES` object:

```typescript
const CLIENT_ACCESS_RULES: Record<string, string[]> = {
  // Client 1: Can only access lender and product endpoints
  'YOUR_CLIENT_ID': ['/lender', '/product'],
  
  // Client 2: Can only access package endpoint
  'another-client-id-here': ['/package'],
  
  // Client 3: Can only access document endpoint
  'yet-another-client-id': ['/document'],
  
  // Clients not listed here will have access to ALL paths (wildcard)
};
```

### Step 2: Create Multiple Cognito App Clients

You'll need to create separate Cognito App Clients for each application that needs different access:

```bash
# Using AWS CLI
aws cognito-idp create-user-pool-client \
  --user-pool-id us-east-1_Wau5rEb2N \
  --client-name "Partner-App-Lender-Only" \
  --generate-secret \
  --allowed-o-auth-flows client_credentials \
  --allowed-o-auth-scopes "iqq-api/read" "iqq-api/write" \
  --allowed-o-auth-flows-user-pool-client
```

Or using Terraform:

```hcl
resource "aws_cognito_user_pool_client" "partner_app" {
  name         = "partner-app-lender-only"
  user_pool_id = aws_cognito_user_pool.main.id
  
  generate_secret = true
  
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = aws_cognito_resource_server.main.scope_identifiers
  
  supported_identity_providers = ["COGNITO"]
}
```

### Step 3: Deploy the Updated Authorizer

```bash
cd iqq-authorizer-service
npm run build
sam build
sam deploy
```

## Examples

### Example 1: Restrict Client to Specific Endpoints

```typescript
const CLIENT_ACCESS_RULES: Record<string, string[]> = {
  // This client can ONLY access /lender and /product
  'abc123-client-id': ['/lender', '/product'],
};
```

**Result:**
- ✅ `GET /dev/lender?lenderId=123` - Allowed
- ✅ `GET /dev/product?productId=456` - Allowed
- ❌ `GET /dev/package?packageId=789` - Denied (403 Forbidden)
- ❌ `GET /dev/document?documentId=101` - Denied (403 Forbidden)

### Example 2: Read-Only Access via Scopes

You can combine path restrictions with scope-based access:

```typescript
// In the authorizer, check scopes
const scopes = decoded.scope?.split(' ') || [];

if (scopes.includes('iqq-api/read') && !scopes.includes('iqq-api/write')) {
  // Only allow GET methods
  const readOnlyResources = allowedResources.map(arn => 
    arn.replace('/*', '/GET/*')
  );
  return generatePolicy(clientId, 'Allow', readOnlyResources, context);
}
```

### Example 3: Environment-Based Access

```typescript
const CLIENT_ACCESS_RULES: Record<string, string[]> = {
  // Development client - full access
  'dev-client-id': ['/lender', '/package', '/product', '/document'],
  
  // Production partner - limited access
  'prod-partner-id': ['/lender', '/product'],
  
  // Internal testing - package only
  'test-client-id': ['/package'],
};
```

## Advanced Configurations

### Option 1: Store Rules in DynamoDB

For dynamic access control without redeploying:

```typescript
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

async function getAllowedResourcesFromDynamoDB(
  clientId: string, 
  apiGatewayArnBase: string
): Promise<string[]> {
  try {
    const result = await dynamoClient.send(new GetCommand({
      TableName: process.env.ACCESS_RULES_TABLE!,
      Key: { clientId }
    }));
    
    if (!result.Item || !result.Item.allowedPaths) {
      // Default: allow all
      return [`${apiGatewayArnBase}/*`];
    }
    
    const allowedPaths = result.Item.allowedPaths as string[];
    return allowedPaths.flatMap(path => [
      `${apiGatewayArnBase}/*${path}`,
      `${apiGatewayArnBase}/*${path}/*`
    ]);
  } catch (error) {
    console.error('Error fetching access rules', { error });
    // Fail closed: deny access on error
    return [];
  }
}
```

**DynamoDB Table Structure:**
```json
{
  "clientId": "abc123-client-id",
  "allowedPaths": ["/lender", "/product"],
  "description": "Partner App - Lender and Product access only",
  "expiresAt": 1735689600
}
```

### Option 2: Use Custom Scopes

Create custom scopes in Cognito for each endpoint:

```hcl
resource "aws_cognito_resource_server" "main" {
  identifier   = "iqq-api"
  name         = "iQQ API"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "lender:read"
    scope_description = "Read access to lender endpoint"
  }
  
  scope {
    scope_name        = "product:read"
    scope_description = "Read access to product endpoint"
  }
  
  scope {
    scope_name        = "package:read"
    scope_description = "Read access to package endpoint"
  }
  
  scope {
    scope_name        = "document:read"
    scope_description = "Read access to document endpoint"
  }
}
```

Then in the authorizer:

```typescript
function getAllowedResourcesByScopes(
  scopes: string[], 
  apiGatewayArnBase: string
): string[] {
  const allowedResources: string[] = [];
  
  if (scopes.includes('iqq-api/lender:read')) {
    allowedResources.push(`${apiGatewayArnBase}/*/lender`);
    allowedResources.push(`${apiGatewayArnBase}/*/lender/*`);
  }
  
  if (scopes.includes('iqq-api/product:read')) {
    allowedResources.push(`${apiGatewayArnBase}/*/product`);
    allowedResources.push(`${apiGatewayArnBase}/*/product/*`);
  }
  
  // ... repeat for other scopes
  
  return allowedResources.length > 0 
    ? allowedResources 
    : [`${apiGatewayArnBase}/*`]; // Default: all access
}
```

### Option 3: Method-Level Restrictions

Restrict specific HTTP methods:

```typescript
const CLIENT_ACCESS_RULES: Record<string, ClientAccessRule> = {
  'client-id-1': {
    paths: [
      { path: '/lender', methods: ['GET'] },           // Read-only
      { path: '/product', methods: ['GET'] },          // Read-only
      { path: '/package', methods: ['GET', 'POST'] },  // Read and write
    ]
  }
};

interface ClientAccessRule {
  paths: Array<{
    path: string;
    methods: string[];
  }>;
}

function getAllowedResources(
  clientId: string, 
  apiGatewayArnBase: string
): string[] {
  const rule = CLIENT_ACCESS_RULES[clientId];
  
  if (!rule) {
    return [`${apiGatewayArnBase}/*`];
  }
  
  const allowedResources: string[] = [];
  
  for (const { path, methods } of rule.paths) {
    for (const method of methods) {
      allowedResources.push(`${apiGatewayArnBase}/${method}${path}`);
      allowedResources.push(`${apiGatewayArnBase}/${method}${path}/*`);
    }
  }
  
  return allowedResources;
}
```

## Testing

### Test 1: Verify Restricted Access

```bash
# Get token for restricted client
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "restricted-client-id:client-secret" \
  -d "grant_type=client_credentials&scope=iqq-api/read" | jq -r '.access_token')

# Try allowed endpoint - should work
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender?lenderId=123" \
  -H "Authorization: Bearer ${TOKEN}"

# Try restricted endpoint - should fail with 403
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package?packageId=456" \
  -H "Authorization: Bearer ${TOKEN}"
```

### Test 2: Check CloudWatch Logs

```bash
aws logs tail /aws/lambda/iqq-authorizer-dev --follow --region us-east-1
```

Look for:
```
Authorization successful { 
  principalId: 'abc123-client-id',
  allowedResources: [
    'arn:aws:execute-api:us-east-1:123456789:api-id/dev/*/lender',
    'arn:aws:execute-api:us-east-1:123456789:api-id/dev/*/lender/*',
    'arn:aws:execute-api:us-east-1:123456789:api-id/dev/*/product',
    'arn:aws:execute-api:us-east-1:123456789:api-id/dev/*/product/*'
  ]
}
```

## Best Practices

### 1. Fail Closed
If there's an error fetching access rules, deny access rather than allowing:

```typescript
try {
  const allowedResources = await getAllowedResourcesFromDynamoDB(clientId, arnBase);
  return generatePolicy(clientId, 'Allow', allowedResources, context);
} catch (error) {
  console.error('Error fetching access rules', { error });
  // Fail closed: deny access
  return generatePolicy(clientId, 'Deny', [`${arnBase}/*`]);
}
```

### 2. Log Access Decisions
Always log which client accessed which endpoint:

```typescript
console.log('Access granted', {
  clientId,
  requestedPath: event.methodArn,
  allowedPaths: CLIENT_ACCESS_RULES[clientId] || 'all'
});
```

### 3. Use Environment Variables
Store client IDs in environment variables for easy updates:

```typescript
const RESTRICTED_CLIENTS = (process.env.RESTRICTED_CLIENTS || '').split(',');

function getAllowedResources(clientId: string, arnBase: string): string[] {
  if (RESTRICTED_CLIENTS.includes(clientId)) {
    // Apply restrictions
    return getRestrictedPaths(clientId, arnBase);
  }
  // Full access
  return [`${arnBase}/*`];
}
```

### 4. Cache Access Rules
Cache DynamoDB lookups to reduce latency:

```typescript
const accessRulesCache = new Map<string, { rules: string[], expiresAt: number }>();

async function getCachedAccessRules(clientId: string): Promise<string[]> {
  const cached = accessRulesCache.get(clientId);
  
  if (cached && cached.expiresAt > Date.now()) {
    return cached.rules;
  }
  
  const rules = await fetchFromDynamoDB(clientId);
  accessRulesCache.set(clientId, {
    rules,
    expiresAt: Date.now() + 300000 // 5 minutes
  });
  
  return rules;
}
```

### 5. Monitor Access Patterns
Set up CloudWatch metrics to track denied requests:

```typescript
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';

async function recordAccessDenied(clientId: string, path: string) {
  const cloudwatch = new CloudWatchClient({});
  
  await cloudwatch.send(new PutMetricDataCommand({
    Namespace: 'iQQ/API',
    MetricData: [{
      MetricName: 'AccessDenied',
      Value: 1,
      Unit: 'Count',
      Dimensions: [
        { Name: 'ClientId', Value: clientId },
        { Name: 'Path', Value: path }
      ]
    }]
  }));
}
```

## Troubleshooting

### Issue: All requests return 403

**Cause**: Access rules are too restrictive or incorrectly formatted

**Solution**: Check CloudWatch logs for the `allowedResources` array. Verify ARN format matches:
```
arn:aws:execute-api:region:account:api-id/stage/METHOD/path
```

### Issue: Caching causes stale permissions

**Cause**: API Gateway caches authorizer responses for 5 minutes

**Solution**: 
- Wait 5 minutes after updating rules
- Or reduce TTL in API Gateway authorizer configuration
- Or change the token to force re-authorization

### Issue: Sub-paths not working

**Cause**: Missing wildcard for sub-paths

**Solution**: Always include both patterns:
```typescript
allowedResources.push(`${arnBase}/*${path}`);      // Exact path
allowedResources.push(`${arnBase}/*${path}/*`);    // Sub-paths
```

## Summary

Path-based access control gives you fine-grained control over which applications can access which endpoints. Choose the approach that best fits your needs:

- **Hardcoded rules**: Simple, fast, requires redeployment
- **DynamoDB rules**: Dynamic, flexible, slight latency
- **Scope-based**: Leverages Cognito features, standard OAuth pattern
- **Hybrid**: Combine multiple approaches for maximum flexibility

The updated authorizer code is ready to use - just configure the `CLIENT_ACCESS_RULES` object and deploy!
