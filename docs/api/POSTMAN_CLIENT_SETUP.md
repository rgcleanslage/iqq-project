# Postman Collection Setup - Client ID Mapping

## Overview
The Postman collection has been updated to support automatic client ID mapping from API keys. Each environment corresponds to a specific client with unique OAuth credentials and API keys.

## What Changed

### Before (v1.1.0)
- Client ID passed as query parameter: `?clientId=CLI001`
- Manual client ID management
- Risk of client ID spoofing

### Now (v1.2.0)
- Client ID automatically extracted from API key tags
- No query parameter needed
- Secure cross-validation between API key and OAuth token
- Each environment has matching OAuth credentials and API key

## Available Environments

### 1. Default Client (CLI001) - Premium Auto Dealership
**File**: `postman-environment-default.json`

**Credentials**:
- Cognito Client ID: `24j8eld9b4h7h0mnsa0b75t8ba`
- Cognito Client Secret: `k8e02n7a4p6vlc0vm8gtdmgp17b0i2suelpn8vrmnkhubglmhji`
- API Key: `YOUR_API_KEY`
- Business Client ID: `CLI001` (auto-extracted from API key)

**Client Preferences**:
- Blocks: APCO Insurance
- Max Providers: 2
- Expected Result: 2 quotes (Client Direct, Route66)

---

### 2. Partner A (CLI002) - Elite Motors Group
**File**: `postman-environment-partner-a.json`

**Credentials**:
- Cognito Client ID: `518u138r9smc4iq9p6sf32e2o4`
- Cognito Client Secret: `130rm5c8mr49mold1rpq23s0nl150ne6l07a54q75nkmm5v55n4c`
- API Key: `hANzeESp9b6eL05ggHNzA8cWJFRULk080plWcZi2`
- Business Client ID: `CLI002` (auto-extracted from API key)

**Client Preferences**:
- Allowed: Client Insurance, Route 66 (whitelist)
- Expected Result: 2 quotes (Client Direct, Route66)

---

### 3. Partner B (CLI003) - Partner B Client
**File**: `postman-environment-partner-b.json`

**Credentials**:
- Cognito Client ID: `4igbgdb4mmmo870serh2ehqcu5`
- Cognito Client Secret: `1kvcs4qcnrbootvu209fm94m2c45o432fjt27m2k808v4vjglss7`
- API Key: `KEIwUBrQ9K3Kzdz7lpxoB5afHFhoyPa76exy05Ox`
- Business Client ID: `CLI003` (auto-extracted from API key)

**Client Preferences**:
- No preferences configured
- Expected Result: All 3 quotes (APCO, Client Direct, Route66)

---

## Setup Instructions

### Step 1: Import Collection
1. Open Postman
2. Click "Import" button
3. Select `postman-collection-fixed.json`
4. Collection will appear in your workspace

### Step 2: Import Environments
Import all three environment files:
1. Click "Import" button
2. Select all environment files:
   - `postman-environment-default.json`
   - `postman-environment-partner-a.json`
   - `postman-environment-partner-b.json`
3. Environments will appear in the environment dropdown

### Step 3: Select Environment
1. Click the environment dropdown (top right)
2. Select the client you want to test:
   - "iQQ Default Client (CLI001)"
   - "iQQ Partner A Client (CLI002)"
   - "iQQ Partner B Client (CLI003)"

### Step 4: Get OAuth Token
1. Expand "Authentication" folder
2. Click "Get OAuth Token (Working)"
3. Click "Send"
4. Token will be automatically saved to environment variable `accessToken`

### Step 5: Test Package Endpoint
1. Expand "Package" folder
2. Click "Get Package (Default Client - CLI001)"
3. Click "Send"
4. Verify response matches expected client preferences

## Testing Different Clients

### Test CLI001 (Default Client)
```
1. Select environment: "iQQ Default Client (CLI001)"
2. Get OAuth Token
3. Send Package request
4. Expected: 2 quotes (APCO blocked, max 2)
```

### Test CLI002 (Partner A)
```
1. Select environment: "iQQ Partner A Client (CLI002)"
2. Get OAuth Token
3. Send Package request
4. Expected: 2 quotes (only Client Direct and Route66)
```

### Test CLI003 (Partner B)
```
1. Select environment: "iQQ Partner B Client (CLI003)"
2. Get OAuth Token
3. Send Package request
4. Expected: 3 quotes (all providers, no preferences)
```

## Security Validation

### Valid Request
When OAuth token and API key match:
```
OAuth Token: client_id=24j8eld9b4h7h0mnsa0b75t8ba → Maps to CLI001
API Key: Tagged with clientId=CLI001
Result: ✅ Success - Request processed
```

### Invalid Request (Mismatch)
When OAuth token and API key don't match:
```
OAuth Token: client_id=24j8eld9b4h7h0mnsa0b75t8ba → Maps to CLI001
API Key: Tagged with clientId=CLI002
Result: ❌ 403 Forbidden - Client ID mismatch
```

To test this scenario:
1. Select "iQQ Default Client (CLI001)" environment
2. Get OAuth Token
3. Manually change `apiKey` variable to Partner A's key
4. Send Package request
5. Should receive 403 Forbidden

## Environment Variables

Each environment includes:

| Variable | Description | Example |
|----------|-------------|---------|
| baseUrl | API Gateway URL | https://r8ukhidr1m.execute-api... |
| cognitoUrl | Cognito domain | https://iqq-dev-ib9i1hvt.auth... |
| clientId | Cognito app client ID | 24j8eld9b4h7h0mnsa0b75t8ba |
| clientSecret | Cognito app client secret | k8e02n7a4p6vlc0vm8gtdmgp17b0... |
| apiKey | API Gateway API key | Ni69xOrTsr5iu0zpiAdkM6Yv0OGj... |
| businessClientId | Business client ID (reference) | CLI001 |
| accessToken | OAuth token (auto-populated) | eyJraWQiOiJxSW5UR2Ey... |
| tokenExpiry | Token expiry time (auto-populated) | 1771437600000 |

## Collection Requests

### Authentication
- **Get OAuth Token (Working)**: Obtains OAuth token with automatic credential encoding

### Package
- **Get Package (Default Client - CLI001)**: Test with automatic client ID mapping
- **Get Package (With Client Preferences - CLI001)**: DEPRECATED - Same as default
- **Get Package (With Client Preferences - CLI002)**: DEPRECATED - Use Partner A environment

### Other Endpoints
- **Get Lender**: Test lender service
- **Get Product**: Test product service
- **Get Document**: Test document service

## Troubleshooting

### Issue: "Unauthorized" (401)
**Cause**: OAuth token expired or invalid
**Solution**: 
1. Run "Get OAuth Token (Working)" again
2. Verify clientId and clientSecret in environment

### Issue: "Forbidden" (403) - "Client ID mismatch"
**Cause**: API key doesn't match OAuth token's client
**Solution**:
1. Verify you're using the correct environment
2. Check that apiKey matches the selected client
3. Don't manually modify apiKey variable

### Issue: "Forbidden" (403) - "Invalid API key"
**Cause**: API key is incorrect or disabled
**Solution**:
1. Verify API key in environment matches Terraform output
2. Check API key is enabled in AWS Console

### Issue: Wrong number of quotes returned
**Cause**: Using wrong environment or client preferences not applied
**Solution**:
1. Verify correct environment is selected
2. Check CloudWatch logs for client ID resolution
3. Verify client preferences in DynamoDB

## Advanced Usage

### Testing Client ID Mismatch
To test the security validation:

```javascript
// In Postman Pre-request Script
const wrongApiKey = "hANzeESp9b6eL05ggHNzA8cWJFRULk080plWcZi2"; // Partner A key
pm.environment.set("apiKey", wrongApiKey);
```

This will cause a 403 Forbidden response if using Default Client OAuth token.

### Viewing Client ID in Response
The client ID is logged in CloudWatch but not returned in the API response. To verify:

```bash
aws logs tail /aws/lambda/iqq-package-service-dev --since 5m --region us-east-1 | grep clientId
```

## Migration from v1.1.0

If you're using the old collection with `clientId` query parameters:

1. **Remove query parameters**: The `clientId` query parameter is no longer needed
2. **Update environments**: Import the new environment files with correct credentials
3. **Match credentials**: Ensure OAuth credentials and API key match for each client
4. **Test**: Verify each client returns expected results

## References

- [CLIENT_CREDENTIALS_MAPPING.md](CLIENT_CREDENTIALS_MAPPING.md) - Full credential mapping
- [API_KEY_CLIENT_MAPPING.md](../architecture/API_KEY_CLIENT_MAPPING.md) - Technical implementation
- [CLIENT_PREFERENCES_GUIDE.md](../architecture/CLIENT_PREFERENCES_GUIDE.md) - Client preferences system

## Date Created
February 18, 2026

## Last Updated
February 18, 2026
