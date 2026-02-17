# API Key Authentication Behavior

## Overview

The iQQ API uses a dual authentication mechanism:
1. OAuth 2.0 access tokens (via AWS Cognito)
2. API keys (stored in DynamoDB)

Both are required for all API requests. This document explains how API keys are managed and validated.

## API Key Storage

API keys are stored in the DynamoDB table `iqq-config-{environment}` with the following structure:

```
PK: 'API_KEY'
SK: <api-key-value>
apiKey: <api-key-value>
clientId: <client-identifier>
name: <human-readable-name>
status: 'active' | 'inactive'
createdAt: <ISO-8601-timestamp>
updatedAt: <ISO-8601-timestamp>
```

## How It Works

### 1. Request Flow

```
Client Request
    ↓
API Gateway
    ↓
Lambda Authorizer (validates both OAuth token + API key)
    ↓
Backend Lambda (if authorized)
```

### 2. Authorizer Validation

The Lambda authorizer (`iqq-authorizer-{env}`) performs the following checks:

1. Extracts `Authorization: Bearer <token>` header
2. Extracts `x-api-key: <api-key>` header
3. Validates OAuth token with Cognito JWKS
4. Queries DynamoDB for API key with status='active'
5. Returns Allow/Deny policy to API Gateway

### 3. API Key Caching

To minimize DynamoDB queries, the authorizer caches API keys in memory:
- Cache TTL: 5 minutes
- Cache is refreshed automatically when expired
- Cache is per Lambda container (warm start optimization)

## Managing API Keys

### Adding New API Keys

Use the provided script to generate and add new API keys:

```bash
cd scripts
npm install
ts-node add-api-keys.ts
```

This will:
- Generate cryptographically secure random API keys
- Add them to DynamoDB with status='active'
- Display the keys (save them securely!)

### Manual API Key Creation

You can also add API keys manually using AWS CLI:

```bash
aws dynamodb put-item \
  --table-name iqq-config-dev \
  --item '{
    "PK": {"S": "API_KEY"},
    "SK": {"S": "your-api-key-here"},
    "apiKey": {"S": "your-api-key-here"},
    "clientId": {"S": "client-id"},
    "name": {"S": "Client Name"},
    "status": {"S": "active"},
    "createdAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"},
    "updatedAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
  }
```

### Revoking API Keys

To revoke an API key, update its status to 'inactive':

```bash
aws dynamodb update-item \
  --table-name iqq-config-dev \
  --key '{"PK": {"S": "API_KEY"}, "SK": {"S": "api-key-to-revoke"}}' \
  --update-expression "SET #status = :inactive, updatedAt = :now" \
  --expression-attribute-names '{"#status": "status"}' \
  --expression-attribute-values '{":inactive": {"S": "inactive"}, ":now": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}}'
```

The authorizer will automatically pick up the change within 5 minutes (cache TTL).

### Rotating API Keys

To rotate an API key:

1. Generate a new API key
2. Add it to DynamoDB with status='active'
3. Provide the new key to the client
4. After client migration, revoke the old key

## Testing API Keys

### Using curl

```bash
# Get OAuth token first
TOKEN=$(curl -X POST https://iqq-auth.auth.us-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET" \
  | jq -r '.access_token')

# Make API request with both OAuth token and API key
curl -X GET https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/products \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: YOUR_API_KEY"
```

### Using Postman

1. Set Authorization header: `Bearer <oauth-token>`
2. Add custom header: `x-api-key: <your-api-key>`
3. Send request

## Security Best Practices

1. **Never commit API keys to version control**
   - Use environment variables or secrets management
   - Rotate any exposed keys immediately

2. **Use different API keys per client**
   - Easier to track usage
   - Easier to revoke access for specific clients

3. **Monitor API key usage**
   - Check CloudWatch logs for authorization failures
   - Set up alarms for suspicious activity

4. **Rotate API keys regularly**
   - Recommended: every 90 days
   - Immediately after employee departure

5. **Use HTTPS only**
   - API keys are transmitted in headers
   - Never use HTTP in production

## Troubleshooting

### 401 Unauthorized - Invalid API key

Check:
- API key is correct (no typos)
- API key exists in DynamoDB
- API key status is 'active'
- Using correct environment (dev/prod)

### 401 Unauthorized - Invalid OAuth token

Check:
- OAuth token is valid and not expired
- Token is from correct Cognito user pool
- Token type is 'access' (not 'id')

### API key validation is slow

- Check DynamoDB throttling metrics
- Consider increasing cache TTL (currently 5 minutes)
- Check Lambda cold start times

## Migration from Environment Variables

Previously, API keys were stored in Lambda environment variables. This has been changed to DynamoDB for better security and management.

If you have old API keys in environment variables:
1. Add them to DynamoDB using the script
2. Remove them from Lambda environment variables
3. Redeploy the authorizer function

The old hardcoded API key `Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH` has been exposed in git history and should be considered compromised. Generate new keys using the script.
