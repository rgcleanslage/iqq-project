---
inclusion: auto
description: Authentication and authorization patterns including dual auth model (OAuth + API keys), custom TOKEN authorizer, and Cognito configuration
---

# Authentication & Authorization

This project uses dual authentication with OAuth 2.0 and API keys.

## Authentication Architecture

### Dual Authentication Model
**Both** OAuth token AND API key are required for all API requests:

1. **OAuth 2.0 Access Token** (via Cognito)
   - Validates user/client identity
   - Provides scopes (read, write)
   - Short-lived (1 hour)

2. **API Key** (via API Gateway)
   - Identifies partner/client
   - Enables usage tracking
   - Rate limiting per key

### Custom Lambda Authorizer

**Type**: TOKEN authorizer (not COGNITO_USER_POOLS)

**Why TOKEN?** COGNITO_USER_POOLS only works with ID tokens. We use client_credentials flow which returns access tokens, so we need a custom TOKEN authorizer.

```yaml
# API Gateway Authorizer Configuration
Type: TOKEN
AuthorizerUri: !Sub arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${AuthorizerArn}/invocations
IdentitySource: method.request.header.Authorization
AuthorizerResultTtlInSeconds: 300
```

### Authorizer Implementation

```typescript
// iqq-providers/authorizer/src/token-authorizer.ts
import jwksClient from 'jwks-rsa';
import jwt from 'jsonwebtoken';

const client = jwksClient({
  jwksUri: `https://cognito-idp.${REGION}.amazonaws.com/${USER_POOL_ID}/.well-known/jwks.json`
});

export const handler = async (event: any) => {
  const token = event.authorizationToken.replace('Bearer ', '');
  
  // Decode token to get kid
  const decoded = jwt.decode(token, { complete: true });
  
  // Get signing key
  const key = await client.getSigningKey(decoded.header.kid);
  const signingKey = key.getPublicKey();
  
  // Verify token
  const verified = jwt.verify(token, signingKey, {
    algorithms: ['RS256'],
    audience: CLIENT_ID,
    issuer: `https://cognito-idp.${REGION}.amazonaws.com/${USER_POOL_ID}`
  });
  
  // Generate IAM policy
  return {
    principalId: verified.sub,
    policyDocument: {
      Version: '2012-10-17',
      Statement: [{
        Action: 'execute-api:Invoke',
        Effect: 'Allow',
        Resource: event.methodArn
      }]
    },
    context: {
      userId: verified.sub,
      clientId: verified.client_id,
      scopes: verified.scope
    }
  };
};
```

## Cognito Configuration

### User Pool Settings
- Pool ID: `us-east-1_Wau5rEb2N`
- Region: `us-east-1`
- App Client ID: `25oa5u3vup2jmhl270e7shudkl`

### OAuth 2.0 Flows

#### Client Credentials Flow (Machine-to-Machine)
Used for partner integrations and system-to-system communication.

```bash
# Get access token
curl -X POST https://iqq-auth-dev.auth.us-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic $(echo -n 'CLIENT_ID:CLIENT_SECRET' | base64)" \
  -d "grant_type=client_credentials&scope=api/read api/write"

# Response
{
  "access_token": "eyJraWQiOiJ...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Important**: Returns `access_token`, not `id_token`. This is why we need a custom TOKEN authorizer.

#### Authorization Code Flow (User Authentication)
Used for web/mobile applications with user login.

```
1. Redirect to Cognito hosted UI
2. User logs in
3. Cognito redirects with authorization code
4. Exchange code for tokens (access_token, id_token, refresh_token)
```

### Scopes
- `api/read`: Read-only access to resources
- `api/write`: Create/update/delete resources

## API Key Management

### API Keys
- Default: `Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH`
- Partner A: (Premium plan)
- Partner B: (Standard plan)

### Usage Plans
```terraform
resource "aws_api_gateway_usage_plan" "standard" {
  name = "standard-plan"
  
  quota_settings {
    limit  = 10000
    period = "MONTH"
  }
  
  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }
}
```

### API Key Validation
API Gateway validates API keys **natively** before invoking Lambda. No code needed in Lambda functions.

```bash
# Request with both auth methods
curl -X GET https://API_ID.execute-api.us-east-1.amazonaws.com/dev/lender \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "x-api-key: API_KEY"
```

## Request Flow

```
1. Client Request
   ├─ Header: Authorization: Bearer <access_token>
   └─ Header: x-api-key: <api_key>
   
2. API Gateway
   ├─ Validate API key (native)
   │  ├─ Check key exists
   │  ├─ Check usage plan limits
   │  └─ Check rate limits
   │
   └─ Invoke Custom Authorizer
      ├─ Extract Bearer token
      ├─ Decode JWT
      ├─ Get signing key from JWKS
      ├─ Verify signature
      ├─ Validate claims (aud, iss, exp)
      └─ Generate IAM policy
      
3. Lambda Function
   └─ Access user context from event.requestContext.authorizer
```

## Error Responses

### 401 Unauthorized
**Causes**:
- Missing Authorization header
- Invalid/expired OAuth token
- Token signature verification failed
- Invalid audience or issuer

**Solution**: Get fresh token from Cognito

### 403 Forbidden
**Causes**:
- Missing x-api-key header
- Invalid API key
- Rate limit exceeded
- Quota exceeded

**Solution**: Check API key, wait for rate limit reset

## Testing Authentication

### Get OAuth Token and API Key

**CRITICAL**: Both OAuth token AND API key are required for all API requests.

```bash
# Get client secret and API key from Secrets Manager
CLIENT_ID=$(aws secretsmanager get-secret-value \
  --region us-east-1 \
  --secret-id iqq-dev-cognito-client-default \
  --query SecretString --output text | jq -r '.client_id')

CLIENT_SECRET=$(aws secretsmanager get-secret-value \
  --region us-east-1 \
  --secret-id iqq-dev-cognito-client-default \
  --query SecretString --output text | jq -r '.client_secret')

API_KEY=$(aws secretsmanager get-secret-value \
  --region us-east-1 \
  --secret-id iqq-dev-api-key-default \
  --query SecretString --output text | jq -r '.api_key')

# Get OAuth access token using client credentials flow
ACCESS_TOKEN=$(curl -X POST https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic $(echo -n "$CLIENT_ID:$CLIENT_SECRET" | base64)" \
  -d "grant_type=client_credentials&scope=iqq-api/read iqq-api/write" \
  -s | jq -r '.access_token')

echo "Access Token: $ACCESS_TOKEN"
echo "API Key: $API_KEY"
```

### Test API Request

**Always include BOTH headers**:

```bash
# Test lender endpoint
curl -X GET https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-api-key: $API_KEY" \
  -v

# Test package endpoint
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-api-key: $API_KEY" \
  -s | jq '.'
```

### Quick Test Script

Save this as `test-api.sh`:

```bash
#!/bin/bash

# Get credentials from Secrets Manager
CLIENT_SECRET=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id iqq-dev-cognito-client-default --query SecretString --output text | jq -r '.client_secret')
API_KEY=$(aws secretsmanager get-secret-value --region us-east-1 --secret-id iqq-dev-api-key-default --query SecretString --output text | jq -r '.api_key')

# Get OAuth token
ACCESS_TOKEN=$(curl -X POST https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic $(echo -n "$CLIENT_ID:$CLIENT_SECRET" | base64)" \
  -d "grant_type=client_credentials&scope=iqq-api/read iqq-api/write" \
  -s | jq -r '.access_token')

# Test endpoint
curl -X GET "$1" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-api-key: $API_KEY" \
  -s | jq '.'
```

Usage:
```bash
chmod +x test-api.sh
./test-api.sh "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender"
./test-api.sh "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60"
```

## Security Best Practices

### Token Handling
1. **Never log tokens**: Redact in logs
2. **Short TTL**: 1 hour for access tokens
3. **Secure storage**: Use secure storage on client
4. **HTTPS only**: Never send over HTTP

### API Key Handling
1. **Environment variables**: Never hardcode
2. **Rotation**: Rotate keys periodically
3. **Per-partner keys**: Unique key per partner
4. **Monitor usage**: Track usage patterns

### Authorizer Best Practices
1. **Cache results**: 300 second TTL
2. **Validate all claims**: aud, iss, exp, nbf
3. **Error handling**: Return 401 for auth failures
4. **Logging**: Log auth attempts (without tokens)

## Troubleshooting

### Authorizer CloudWatch Logs
```bash
# View authorizer logs
aws logs tail /aws/lambda/iqq-authorizer-dev --follow
```

### Common Issues

**"Token is expired"**
- Get fresh token from Cognito
- Check system clock sync

**"Invalid signature"**
- Verify JWKS URI is correct
- Check Cognito User Pool ID

**"Audience validation failed"**
- Verify CLIENT_ID matches token audience
- Check app client configuration

**"API key not found"**
- Verify x-api-key header is present
- Check API key is associated with usage plan

## Environment Variables

### Authorizer Lambda
```yaml
Environment:
  Variables:
    COGNITO_USER_POOL_ID: us-east-1_Wau5rEb2N
    COGNITO_CLIENT_ID: 25oa5u3vup2jmhl270e7shudkl
    AWS_REGION: us-east-1
```

### API Gateway
```terraform
variable "api_gateway_id" {
  default = "r8ukhidr1m"
}

variable "default_api_key" {
  default = "Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH"
}
```

## References

- #[[file:docs/api/CLIENT_CREDENTIALS_MAPPING.md]]
- #[[file:docs/api/SECRETS_MANAGEMENT.md]]
- #[[file:docs/deployment/COGNITO_AUTHORIZER_ISSUE.md]]
- Cognito User Pool: https://console.aws.amazon.com/cognito/v2/idp/user-pools/us-east-1_Wau5rEb2N
- API Gateway: https://console.aws.amazon.com/apigateway/main/apis/r8ukhidr1m
