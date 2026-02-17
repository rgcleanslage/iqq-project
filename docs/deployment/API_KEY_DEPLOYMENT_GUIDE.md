# API Key Deployment Guide

## Overview

This guide documents the migration from environment variable-based API key storage to DynamoDB-based storage for the iQQ API authorizer.

## What Changed

### Before
- API keys were stored in Lambda environment variables
- Keys were hardcoded in `template.yaml`
- Difficult to rotate keys without redeployment
- Keys visible in AWS Console

### After
- API keys stored in DynamoDB table `iqq-config-{env}`
- Keys loaded dynamically with 5-minute cache
- Easy rotation without redeployment
- Keys not visible in Lambda configuration

## Deployment Steps

### 1. Add API Keys to DynamoDB

Run the provided script to generate and add API keys:

```bash
cd scripts
npm install
npx ts-node add-api-keys.ts
```

This will:
- Generate 3 secure random API keys (default, partner-a, partner-b)
- Add them to DynamoDB with status='active'
- Display the keys (save them securely!)

### 2. Deploy Updated Authorizer

The authorizer has been updated to:
- Load API keys from DynamoDB on cold start
- Cache keys for 5 minutes
- Refresh cache automatically when expired

Deploy using GitHub Actions:
```bash
gh workflow run ci-cd.yml --repo rgcleanslage/iqq-providers --ref main --field environment=dev
```

Or manually:
```bash
cd iqq-providers
sam build
sam deploy --config-env dev
```

### 3. Test API with New Keys

```bash
# Get OAuth token
TOKEN=$(curl -X POST https://iqq-auth.auth.us-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET" \
  | jq -r '.access_token')

# Test API with new API key
curl -X GET https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/products \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: YOUR_NEW_API_KEY"
```

## API Key Management

### Adding New Keys

```bash
aws dynamodb put-item \
  --table-name iqq-config-dev \
  --item '{
    "PK": {"S": "API_KEY"},
    "SK": {"S": "new-api-key-here"},
    "apiKey": {"S": "new-api-key-here"},
    "clientId": {"S": "client-id"},
    "name": {"S": "Client Name"},
    "status": {"S": "active"},
    "createdAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"},
    "updatedAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
  }
```

### Revoking Keys

```bash
aws dynamodb update-item \
  --table-name iqq-config-dev \
  --key '{"PK": {"S": "API_KEY"}, "SK": {"S": "api-key-to-revoke"}}' \
  --update-expression "SET #status = :inactive, updatedAt = :now" \
  --expression-attribute-names '{"#status": "status"}' \
  --expression-attribute-values '{":inactive": {"S": "inactive"}, ":now": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}}'
```

### Listing Active Keys

```bash
aws dynamodb query \
  --table-name iqq-config-dev \
  --key-condition-expression "PK = :pk" \
  --filter-expression "#status = :active" \
  --expression-attribute-names '{"#status": "status"}' \
  --expression-attribute-values '{":pk": {"S": "API_KEY"}, ":active": {"S": "active"}}'
```

## Security Considerations

1. **Old Exposed Key**: The key `Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH` was exposed in git history and should be considered compromised. It has been removed from the codebase.

2. **New Keys**: The script generates cryptographically secure random keys using Node.js `crypto.randomBytes()`.

3. **Key Rotation**: Rotate keys every 90 days or immediately after:
   - Employee departure
   - Security incident
   - Suspected compromise

4. **Access Control**: Limit DynamoDB table access to:
   - Lambda execution role (read-only)
   - Admin users (read/write)
   - CI/CD pipeline (no access needed)

## Troubleshooting

### API returns 401 with valid token and key

Check:
1. API key exists in DynamoDB: `aws dynamodb get-item --table-name iqq-config-dev --key '{"PK": {"S": "API_KEY"}, "SK": {"S": "your-key"}}'`
2. API key status is 'active'
3. Cache may be stale (wait 5 minutes or redeploy)

### Authorizer logs show DynamoDB errors

Check:
1. Lambda has DynamoDB read permissions
2. Table name is correct in environment variables
3. AWS credentials are valid

### Performance issues

- Current cache TTL: 5 minutes
- Consider increasing if API key changes are infrequent
- Monitor DynamoDB read capacity

## Files Changed

- `iqq-providers/authorizer/src/request-authorizer.ts` - Updated to load from DynamoDB
- `iqq-providers/template.yaml` - Removed hardcoded API key
- `iqq-providers/authorizer/tests/request-authorizer.test.ts` - Updated tests to mock DynamoDB
- `scripts/add-api-keys.ts` - New script to generate and add keys
- `docs/deployment/API_KEY_BEHAVIOR.md` - Detailed behavior documentation

## Deployment Status

- ✅ Code changes committed and pushed
- ✅ API keys added to DynamoDB (3 keys: default, partner-a, partner-b)
- ✅ Authorizer deployed successfully
- ✅ Tests passing
- ⏳ Pending: Test API with new keys
- ⏳ Pending: Rotate old exposed key in production

## Next Steps

1. Test API endpoints with new API keys
2. Update client applications with new keys
3. Monitor CloudWatch logs for authorization errors
4. Set up key rotation schedule (90 days)
5. Document key distribution process for partners
