# Client Credentials Mapping

## Overview
Each API key is now tagged with a `clientId` that automatically maps to client preferences in DynamoDB. The package service extracts the client ID from the API key tags and validates it against the OAuth token's client_id for security.

## API Key to Client ID Mapping

### Default API Key → CLI001
**Use Case**: Premium Auto Dealership (internal testing, default access)

**API Key**:
- Key ID: `em0rsslt3f`
- Key Value: `YOUR_API_KEY`
- Tagged with: `clientId=CLI001`

**OAuth Credentials**:
- Client ID: `24j8eld9b4h7h0mnsa0b75t8ba`
- Client Secret: `k8e02n7a4p6vlc0vm8gtdmgp17b0i2suelpn8vrmnkhubglmhji`
- Client Name: `iqq-default-client-dev`

**Client Preferences** (CLI001):
- Blocked Providers: APCO
- Max Providers: 2

**Usage Plan**: Standard (10,000 requests/month, 50 req/sec)

---

### Partner A API Key → CLI002
**Use Case**: Elite Motors Group (premium partner with higher rate limits)

**API Key**:
- Key ID: `kzsfzx6075`
- Key Value: (retrieve with `terraform output partner_a_api_key_value`)
- Tagged with: `clientId=CLI002`

**OAuth Credentials**:
- Client ID: `518u138r9smc4iq9p6sf32e2o4`
- Client Secret: `130rm5c8mr49mold1rpq23s0nl150ne6l07a54q75nkmm5v55n4c`
- Client Name: `iqq-partner_a-client-dev`

**Client Preferences** (CLI002):
- Allowed Providers: Client Direct, Route66 (whitelist - only these providers)

**Usage Plan**: Premium (100,000 requests/month, 200 req/sec)

---

### Partner B API Key → CLI003
**Use Case**: Partner B Client (standard partner)

**API Key**:
- Key ID: `lpmo44akaj`
- Key Value: (retrieve with `terraform output partner_b_api_key_value`)
- Tagged with: `clientId=CLI003`

**OAuth Credentials**:
- Client ID: `4igbgdb4mmmo870serh2ehqcu5`
- Client Secret: `1kvcs4qcnrbootvu209fm94m2c45o432fjt27m2k808v4vjglss7`
- Client Name: `iqq-partner_b-client-dev`

**Client Preferences** (CLI003):
- No preferences configured (returns all providers)

**Usage Plan**: Standard (10,000 requests/month, 50 req/sec)

---

### Legacy Client (Deprecated)
**Use Case**: Backward compatibility only

**OAuth Credentials**:
- Client ID: `YOUR_CLIENT_ID`
- Client Secret: `YOUR_CLIENT_SECRET`
- Client Name: `iqq-app-client-dev`

**Note**: This client can be used with any API key but is maintained for backward compatibility. New integrations should use partner-specific clients.

---

## How It Works

### Automatic Client ID Resolution
1. **API Request**: Client sends request with OAuth token (Bearer) + API key (x-api-key header)
2. **API Gateway**: Validates both OAuth token (via Lambda authorizer) and API key
3. **Package Service**: 
   - Extracts API key ID from `event.requestContext.identity.apiKeyId`
   - Calls API Gateway GetApiKey to retrieve tags
   - Extracts `clientId` from tags
   - Extracts `client_id` from OAuth token JWT payload
   - Validates that API key's clientId matches token's client_id
   - If mismatch: Returns 403 Forbidden
   - If match: Uses clientId for provider filtering
4. **Provider Loader**: Applies client preferences from DynamoDB based on clientId

### Security Validation
The system enforces that the API key's client ID must match the OAuth token's client ID:

```
API Key Tag: clientId=CLI001
OAuth Token: client_id=24j8eld9b4h7h0mnsa0b75t8ba (maps to CLI001)
Result: ✅ Allowed

API Key Tag: clientId=CLI001  
OAuth Token: client_id=518u138r9smc4iq9p6sf32e2o4 (maps to CLI002)
Result: ❌ 403 Forbidden - Client ID mismatch
```

This prevents clients from using another client's API key even if they have valid OAuth credentials.

---

## Authentication Flow

Each client follows the OAuth 2.0 Client Credentials flow with API key validation:

```bash
# 1. Get OAuth token
curl -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "CLIENT_ID:CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=iqq-api/read"

# 2. Use token + API key for API calls (client ID is automatically extracted from API key tags)
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "x-api-key: API_KEY_VALUE"
```

**Note**: The `clientId` is now automatically extracted from the API key tags. You no longer need to pass it as a query parameter.

## Security Benefits

### 1. Automatic Client ID Mapping
- Client ID is tagged on API keys in API Gateway
- Package service automatically retrieves clientId from API key tags
- No manual client ID passing required
- Prevents client ID spoofing

### 2. Cross-Validation
- API key's clientId must match OAuth token's client_id
- Prevents clients from using another client's API key
- Returns 403 Forbidden on mismatch
- Enforced at the Lambda function level

### 3. Isolation
- Each partner has unique OAuth credentials and API key
- Compromised credentials affect only one partner
- Easy to revoke access per partner
- Client preferences isolated by clientId

### 4. Tracking
- CloudWatch logs show which client made requests
- Usage metrics per client via API Gateway
- Audit trail per partner
- Client ID logged in all Lambda invocations

### 5. Rate Limiting
- API keys enforce rate limits via usage plans
- OAuth tokens provide authentication
- Double layer of protection
- Per-client quotas and throttling

### 6. Provider Filtering
- Client preferences stored in DynamoDB by clientId
- Automatic filtering based on client preferences
- Supports blocklist, whitelist, preferred providers, max providers
- Transparent to API consumers

## Retrieving Credentials

### Get All Client IDs
```bash
terraform output -json cognito_partner_clients | jq .
```

### Get All Client Secrets
```bash
terraform output -json cognito_partner_client_secrets | jq -r 'to_entries[] | "\(.key): \(.value)"'
```

### Get Specific Partner Credentials
```bash
# Partner A
terraform output -json cognito_partner_clients | jq -r '.partner_a.client_id'
terraform output -json cognito_partner_client_secrets | jq -r '.partner_a'

# Partner B
terraform output -json cognito_partner_clients | jq -r '.partner_b.client_id'
terraform output -json cognito_partner_client_secrets | jq -r '.partner_b'
```

### Get API Keys
```bash
# Default
terraform output -raw default_api_key_value

# Partner A
terraform output -raw partner_a_api_key_value

# Partner B
terraform output -raw partner_b_api_key_value
```

## Testing Each Client

### Test Default Client (CLI001)
```bash
CLIENT_ID="24j8eld9b4h7h0mnsa0b75t8ba"
CLIENT_SECRET="k8e02n7a4p6vlc0vm8gtdmgp17b0i2suelpn8vrmnkhubglmhji"
API_KEY="YOUR_API_KEY"

# Get OAuth token
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read" | jq -r '.access_token')

# Test package endpoint (should return max 2 quotes, APCO blocked)
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

### Test Partner A Client (CLI002)
```bash
CLIENT_ID="518u138r9smc4iq9p6sf32e2o4"
CLIENT_SECRET="130rm5c8mr49mold1rpq23s0nl150ne6l07a54q75nkmm5v55n4c"
API_KEY=$(terraform output -raw partner_a_api_key_value)

# Get OAuth token
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read" | jq -r '.access_token')

# Test package endpoint (should return only Client Direct and Route66)
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

### Test Partner B Client (CLI003)
```bash
CLIENT_ID="4igbgdb4mmmo870serh2ehqcu5"
CLIENT_SECRET="1kvcs4qcnrbootvu209fm94m2c45o432fjt27m2k808v4vjglss7"
API_KEY=$(terraform output -raw partner_b_api_key_value)

# Get OAuth token
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read" | jq -r '.access_token')

# Test package endpoint (should return all 3 providers)
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

### Test Client ID Mismatch (Should Fail with 403)
```bash
# Use CLI001's OAuth token with CLI002's API key (should be rejected)
CLIENT_ID="24j8eld9b4h7h0mnsa0b75t8ba"
CLIENT_SECRET="k8e02n7a4p6vlc0vm8gtdmgp17b0i2suelpn8vrmnkhubglmhji"
WRONG_API_KEY=$(terraform output -raw partner_a_api_key_value)

TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read" | jq -r '.access_token')

# This should return 403 Forbidden
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${WRONG_API_KEY}"
```

## Postman Configuration

### Create Separate Environments

#### Environment: Default Client
```json
{
  "clientId": "6rvvvqvvvvvvvvvvvvvvvvvvvv",
  "clientSecret": "k8e02n7a4p6vlc0vm8gtdmgp17b0i2suelpn8vrmnkhubglmhji",
  "apiKey": "YOUR_API_KEY"
}
```

#### Environment: Partner A
```json
{
  "clientId": "518u138r9smc4iq9p6sf32e2o4",
  "clientSecret": "130rm5c8mr49mold1rpq23s0nl150ne6l07a54q75nkmm5v55n4c",
  "apiKey": "YOUR_PARTNER_A_API_KEY"
}
```

#### Environment: Partner B
```json
{
  "clientId": "4igbgdb4mmmo870serh2ehqcu5",
  "clientSecret": "1kvcs4qcnrbootvu209fm94m2c45o432fjt27m2k808v4vjglss7",
  "apiKey": "YOUR_PARTNER_B_API_KEY"
}
```

## Migration Guide

### For Existing Clients
1. Continue using legacy client credentials
2. Gradually migrate to partner-specific clients
3. Update documentation and SDKs
4. Deprecate legacy client after migration

### For New Clients
1. Create new API key in API Gateway
2. Create new Cognito app client
3. Provide both credentials to partner
4. Document in this file

## Adding New Clients

To add a new partner client:

1. **Update Terraform**:
   ```hcl
   # In modules/cognito/main.tf
   for_each = toset(["default", "partner_a", "partner_b", "partner_c"])
   ```

2. **Apply Changes**:
   ```bash
   cd iqq-infrastructure
   terraform plan
   terraform apply
   ```

3. **Retrieve Credentials**:
   ```bash
   terraform output -json cognito_partner_clients | jq -r '.partner_c'
   terraform output -json cognito_partner_client_secrets | jq -r '.partner_c'
   ```

4. **Create API Key** (if needed):
   - Add to `modules/api-gateway/main.tf`
   - Associate with usage plan
   - Deploy changes

5. **Document** in this file

## Security Best Practices

1. **Never commit secrets** - Use environment variables or secure vaults
2. **Rotate regularly** - Update client secrets every 90 days
3. **Monitor usage** - Check CloudWatch logs for anomalies
4. **Revoke compromised** - Immediately disable compromised clients
5. **Separate environments** - Use different credentials for dev/prod

## Support

For credential issues:
- Check CloudWatch logs: `/aws/lambda/iqq-*-service-dev`
- Verify Cognito configuration in AWS Console
- Contact: api-support@iqq.com

## Date Created
February 17, 2026

## Last Updated
February 17, 2026
