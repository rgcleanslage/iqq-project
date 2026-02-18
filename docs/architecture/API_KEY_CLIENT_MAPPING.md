# API Key to Client ID Mapping Implementation

## Overview
This document describes the implementation of automatic client ID mapping from API Gateway API keys to business client IDs, with cross-validation against OAuth tokens for enhanced security.

## Architecture

### Components
1. **API Gateway API Keys**: Tagged with `clientId` (business client ID)
2. **Cognito App Clients**: OAuth credentials with `client_id` (Cognito app client ID)
3. **Package Service**: Extracts and validates client IDs
4. **Provider Loader**: Applies client preferences based on client ID
5. **DynamoDB**: Stores client preferences by client ID

### Flow
```
1. Client Request
   ├─ OAuth Token (Bearer) → Contains Cognito client_id
   └─ API Key (x-api-key) → Tagged with business clientId

2. API Gateway
   ├─ Validates OAuth token via Lambda authorizer
   └─ Validates API key (rate limiting, usage plan)

3. Package Service Lambda
   ├─ Extracts API key ID from event.requestContext.identity.apiKeyId
   ├─ Calls API Gateway GetApiKey to retrieve tags
   ├─ Extracts clientId from tags → "CLI001"
   ├─ Decodes OAuth token JWT payload
   ├─ Extracts client_id from token → "24j8eld9b4h7h0mnsa0b75t8ba"
   ├─ Maps Cognito client_id to business clientId → "CLI001"
   ├─ Validates: API key clientId == OAuth token clientId
   │  ├─ Match: Continue with clientId
   │  └─ Mismatch: Return 403 Forbidden
   └─ Passes clientId to Step Functions

4. Step Functions
   └─ Passes clientId to Provider Loader

5. Provider Loader
   ├─ Queries DynamoDB for client preferences (PK=CLIENT#CLI001, SK=PREFERENCES)
   ├─ Applies filters: blocked → allowed → preferred → max
   └─ Returns filtered provider list

6. Package Service
   └─ Returns aggregated quotes from filtered providers
```

## Implementation Details

### API Key Tags (Terraform)
```hcl
resource "aws_api_gateway_api_key" "default" {
  name        = "iqq-default-key-dev"
  description = "Default API key for testing and development"
  enabled     = true
  
  tags = {
    clientId = "CLI001"
    clientName = "Premium Auto Dealership"
  }
}
```

### Cognito to Client ID Mapping (Package Service)
```typescript
const COGNITO_TO_CLIENT_ID_MAP: Record<string, string> = {
  '24j8eld9b4h7h0mnsa0b75t8ba': 'CLI001', // Default client
  '518u138r9smc4iq9p6sf32e2o4': 'CLI002', // Partner A
  '4igbgdb4mmmo870serh2ehqcu5': 'CLI003', // Partner B
  '25oa5u3vup2jmhl270e7shudkl': 'LEGACY' // Legacy client
};
```

### Client ID Extraction (Package Service)
```typescript
// 1. Get client ID from API key tags
const apiKeyId = event.requestContext?.identity?.apiKeyId;
const clientIdFromApiKey = await getClientIdFromApiKey(apiKeyId);

// 2. Get client ID from OAuth token
const clientIdFromToken = getClientIdFromToken(event);

// 3. Validate match
if (clientIdFromApiKey !== clientIdFromToken) {
  return { statusCode: 403, body: 'Client ID mismatch' };
}

// 4. Use validated client ID
const clientId = clientIdFromApiKey;
```

### IAM Permissions (SAM Template)
```yaml
Policies:
  - Statement:
      - Effect: Allow
        Action:
          - apigateway:GET
        Resource: !Sub 'arn:aws:apigateway:${AWS::Region}::/apikeys/*'
```

## Client Mappings

| Business Client ID | Cognito App Client ID | API Key ID | Client Preferences |
|-------------------|----------------------|------------|-------------------|
| CLI001 | 24j8eld9b4h7h0mnsa0b75t8ba | em0rsslt3f | Blocked: APCO, Max: 2 |
| CLI002 | 518u138r9smc4iq9p6sf32e2o4 | kzsfzx6075 | Allowed: Client Direct, Route66 |
| CLI003 | 4igbgdb4mmmo870serh2ehqcu5 | lpmo44akaj | No preferences (all providers) |
| LEGACY | 25oa5u3vup2jmhl270e7shudkl | N/A | Backward compatibility |

## Security Features

### 1. Automatic Client ID Mapping
- Client ID is tagged on API keys in API Gateway
- Package service automatically retrieves clientId from API key tags
- No manual client ID passing required
- Prevents client ID spoofing via query parameters

### 2. Cross-Validation
- API key's clientId must match OAuth token's client_id (after mapping)
- Prevents clients from using another client's API key
- Returns 403 Forbidden on mismatch
- Enforced at the Lambda function level

### 3. Dual Authentication
- OAuth token validates identity (who you are)
- API key validates authorization (what you can access)
- Both must be valid and match for request to succeed

### 4. Audit Trail
- All client ID resolutions logged to CloudWatch
- Includes: API key ID, Cognito client ID, business client ID
- Mismatch attempts logged with details
- Full request correlation via correlation ID

## Testing

### Test Scenarios
1. **Valid Request**: Matching OAuth token and API key → Success
2. **Client Preferences**: CLI001 blocks APCO, max 2 quotes → 2 quotes returned
3. **Whitelist**: CLI002 only allows Client Direct and Route66 → 2 quotes returned
4. **No Preferences**: CLI003 has no preferences → All 3 providers returned
5. **Mismatch**: CLI001 token with CLI002 API key → 403 Forbidden

### Test Results
```bash
$ ./scripts/test-complete-client-mapping.sh

Test 1: Default Client (CLI001) with matching API key
✅ PASSED: Max 2 quotes enforced, APCO blocked

Test 2: Partner A Client (CLI002) with matching API key
✅ PASSED: Only allowed providers returned

Test 3: Client ID Mismatch (CLI001 token with CLI002 API key)
✅ PASSED: Client ID mismatch correctly rejected (403)

Test 4: Partner B Client (CLI003) with no preferences
✅ PASSED: All providers returned (no preferences)
```

## Benefits

### For Security
- Prevents API key sharing between clients
- Automatic validation without manual checks
- Tamper-proof client ID (from API Gateway tags)
- Full audit trail of all requests

### For Operations
- No manual client ID passing required
- Centralized client management in Terraform
- Easy to add new clients (update Terraform + mapping)
- CloudWatch logs for debugging and monitoring

### For Clients
- Transparent client ID resolution
- No changes to API request format
- Automatic preference enforcement
- Consistent behavior across all endpoints

## Adding New Clients

### 1. Update Terraform (API Gateway)
```hcl
resource "aws_api_gateway_api_key" "partner_c" {
  name = "iqq-partner-c-key-dev"
  tags = {
    clientId = "CLI004"
    clientName = "Partner C Client"
  }
}
```

### 2. Update Cognito Client Mapping (Package Service)
```typescript
const COGNITO_TO_CLIENT_ID_MAP: Record<string, string> = {
  // ... existing mappings
  'new-cognito-client-id': 'CLI004', // Partner C
};
```

### 3. Seed Client Preferences (DynamoDB)
```bash
npm run seed-preferences -- --clientId CLI004 --allowedProviders "APCO,Client Direct"
```

### 4. Deploy Changes
```bash
# Deploy infrastructure
cd iqq-infrastructure && terraform apply

# Deploy package service
cd iqq-package-service && sam build && sam deploy
```

### 5. Test
```bash
# Get new API key
terraform output -raw partner_c_api_key_value

# Test with new credentials
curl -X GET "${API_URL}/package" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

## Troubleshooting

### Issue: "No clientId tag found on API key"
**Cause**: API key tags not applied in Terraform
**Solution**: Run `terraform apply` to update API key tags

### Issue: "Client ID mismatch between API key and OAuth token"
**Cause**: Using wrong API key for the OAuth token
**Solution**: Ensure API key matches the Cognito app client used for OAuth

### Issue: "No mapping found for Cognito client ID"
**Cause**: Cognito client ID not in COGNITO_TO_CLIENT_ID_MAP
**Solution**: Add mapping in package service and redeploy

### Issue: Client preferences not applied
**Cause**: Client ID not passed to Step Functions or DynamoDB
**Solution**: Check CloudWatch logs for clientId in Step Functions input

## Monitoring

### CloudWatch Logs
```bash
# View client ID resolution
aws logs tail /aws/lambda/iqq-package-service-dev --since 5m --region us-east-1 | grep clientId

# View validation failures
aws logs tail /aws/lambda/iqq-package-service-dev --since 5m --region us-east-1 | grep "mismatch"
```

### Metrics to Monitor
- Client ID mismatch rate (403 responses)
- API key usage per client
- Provider filtering effectiveness
- Request latency by client

## Future Enhancements

### Potential Improvements
1. **Dynamic Mapping**: Store Cognito-to-business client ID mapping in DynamoDB
2. **Client Metadata**: Add more client attributes to API key tags
3. **Rate Limiting**: Per-client rate limits based on client ID
4. **Analytics**: Client-specific usage analytics and reporting
5. **Multi-Region**: Support for cross-region client ID resolution

## References
- [CLIENT_CREDENTIALS_MAPPING.md](../api/CLIENT_CREDENTIALS_MAPPING.md) - OAuth credentials and API keys
- [CLIENT_PREFERENCES_GUIDE.md](CLIENT_PREFERENCES_GUIDE.md) - Client preferences system
- [CLIENT_PREFERENCES_IMPLEMENTATION.md](CLIENT_PREFERENCES_IMPLEMENTATION.md) - Technical implementation

## Date Created
February 18, 2026

## Last Updated
February 18, 2026
