# Postman Versioned Collection Setup Guide

Complete guide for using the versioned Postman collection with API versions v1-v9.

## Quick Start

### 1. Import Collection and Environment

1. Open Postman
2. Click **Import** button
3. Import the collection:
   - File: `docs/api/postman-collection-versioned.json`
4. Import an environment template:
   - Default Client: `docs/api/postman-environment-default.template.json`
   - Partner A: `docs/api/postman-environment-partner-a.template.json`
   - Partner B: `docs/api/postman-environment-partner-b.template.json`

### 2. Configure Environment

#### Option A: Using AWS Secrets Manager (Recommended)

Get credentials from AWS Secrets Manager:

```bash
# Get Default Client credentials
aws secretsmanager get-secret-value \
  --secret-id iqq-dev-cognito-client-default \
  --query SecretString --output text | jq .

aws secretsmanager get-secret-value \
  --secret-id iqq-dev-api-key-default \
  --query SecretString --output text | jq .
```

#### Option B: Using Terraform Outputs

Get credentials from Terraform:

```bash
cd iqq-infrastructure

# Get client ID
terraform output -json cognito_partner_clients | jq -r '.default.client_id'

# Get client secret
terraform output -json cognito_partner_client_secrets | jq -r '.default'

# Get API key
terraform output -raw default_api_key_value
```

#### Update Environment Variables

In Postman, select your environment and update:
- `clientId` - Your Cognito client ID
- `clientSecret` - Your Cognito client secret
- `apiKey` - Your API key

### 3. Authenticate

1. Select your environment in Postman (top-right dropdown)
2. Open the collection: **iQQ Insurance Quote API - Versioned**
3. Navigate to: **Authentication** → **Get OAuth Token**
4. Click **Send**
5. Verify you see: `✓ SUCCESS: Token obtained and saved`

The token is automatically saved to your environment and will be used for all subsequent requests.

### 4. Test API Versions

#### Test v1 (Stable)
1. Navigate to: **v1 (Stable)** → **Package** → **Get Package**
2. Click **Send**
3. Verify response includes:
   ```json
   {
     "metadata": {
       "apiVersion": "v1",
       "versionStatus": "stable"
     }
   }
   ```

#### Test v9 (Latest)
1. Navigate to: **v2-v9 (Testing)** → **v9 (Latest)** → **Get Package (v9)**
2. Click **Send**
3. Verify response includes:
   ```json
   {
     "metadata": {
       "apiVersion": "v9",
       "versionStatus": "planned"
     }
   }
   ```

## Collection Structure

### Authentication
- **Get OAuth Token** - Authenticate and get access token

### v1 (Stable)
Complete set of v1 endpoints:
- Package (with query parameters)
- Lender
- Product
- Document

### v2-v9 (Testing)
Sample endpoints for testing versions:
- **v2** - Package endpoint
- **v5** - Package endpoint
- **v9 (Latest)** - All 4 endpoints (Package, Lender, Product, Document)

### Version Comparison
- **Compare v1 vs v9** - Run both requests to compare responses

## Features

### 1. Automatic Token Management
- Pre-request script encodes credentials
- Test script saves token to environment
- Token automatically used in all requests

### 2. Version Metadata Detection
Test scripts automatically:
- Extract version metadata from responses
- Display version and status in console
- Store responses for comparison

### 3. Deprecation Warning
Test scripts check for deprecation headers:
- `X-API-Deprecation-Date`
- `X-API-Sunset-Date`
- `X-API-Migration-Guide`

Warnings displayed in console if version is deprecated.

### 4. Version Comparison
Run comparison requests to:
- Store v1 and v9 responses
- Compare version metadata
- Analyze differences

## Environment Variables

### Required (Set by User)
- `clientId` - Cognito client ID
- `clientSecret` - Cognito client secret
- `apiKey` - API key for authentication

### Automatic (Set by Scripts)
- `accessToken` - OAuth access token
- `tokenExpiry` - Token expiration timestamp
- `v1_response` - Stored v1 response
- `v1_version` - v1 version metadata
- `v1_status` - v1 version status
- `v9_response` - Stored v9 response
- `v9_version` - v9 version metadata
- `v9_status` - v9 version status

### Configuration
- `baseUrl` - Base API URL (without version)
- `cognitoUrl` - Cognito OAuth endpoint
- `businessClientId` - Business client ID (CLI001, CLI002, CLI003)
- `currentVersion` - Current version to use (v1-v9)

## Testing Different Versions

### Test All Versions
To test all versions, manually change the version in the URL:

```
v1: {{baseUrl}}/v1/package
v2: {{baseUrl}}/v2/package
v3: {{baseUrl}}/v3/package
v4: {{baseUrl}}/v4/package
v5: {{baseUrl}}/v5/package
v6: {{baseUrl}}/v6/package
v7: {{baseUrl}}/v7/package
v8: {{baseUrl}}/v8/package
v9: {{baseUrl}}/v9/package
```

### Version Status
Each version has a status:
- **planned** - Created but not deployed
- **alpha** - Early testing
- **beta** - Feature complete, testing
- **stable** - Production ready
- **deprecated** - Scheduled for removal
- **sunset** - No longer available

Check the `versionStatus` field in response metadata.

## Client Preferences

Each environment uses different client preferences:

### Default Client (CLI001)
- Blocks APCO Insurance
- Max 2 providers
- Expected: 2 quotes (Client Direct, Route66)

### Partner A (CLI002)
- Whitelist: Client Insurance, Route 66
- Expected: 2 quotes (Client Direct, Route66)

### Partner B (CLI003)
- No preferences
- Expected: 3 quotes (APCO, Client Direct, Route66)

## Troubleshooting

### 401 Unauthorized
**Problem:** Token expired or invalid

**Solution:**
1. Run **Get OAuth Token** again
2. Verify `clientId` and `clientSecret` are correct
3. Check token in environment variables

### 403 Forbidden
**Problem:** Missing or invalid API key

**Solution:**
1. Verify `apiKey` is set in environment
2. Check API key is valid in AWS Console
3. Ensure API key is in usage plan

### No Version Metadata
**Problem:** Response doesn't include version metadata

**Solution:**
1. Verify you're using versioned URLs (e.g., `/v1/package`)
2. Check Lambda environment variables are set
3. Ensure services are deployed with version aliases

### Deprecation Headers Not Showing
**Problem:** Version is deprecated but no headers

**Solution:**
1. Check version status in GitHub Release
2. Verify Lambda environment variables:
   - `VERSION_STATUS`
   - `VERSION_SUNSET_DATE`
3. Ensure response-builder.ts is using env vars

## Advanced Usage

### Running Tests Programmatically

Use Postman CLI (newman) to run tests:

```bash
# Install newman
npm install -g newman

# Run collection
newman run docs/api/postman-collection-versioned.json \
  --environment docs/api/postman-environment-default.json \
  --reporters cli,json

# Run specific folder
newman run docs/api/postman-collection-versioned.json \
  --folder "v1 (Stable)" \
  --environment docs/api/postman-environment-default.json
```

### CI/CD Integration

Add to GitHub Actions:

```yaml
- name: Test API with Postman
  run: |
    npm install -g newman
    newman run docs/api/postman-collection-versioned.json \
      --environment docs/api/postman-environment-default.json \
      --reporters cli,junit \
      --reporter-junit-export results.xml
```

## Related Documentation

- [API Documentation](./README.md) - API overview
- [API Versioning Guide](../deployment/API_VERSIONING_WITH_GITHUB_RELEASES.md) - Version management
- [Postman Troubleshooting](./POSTMAN_TROUBLESHOOTING.md) - Common issues
- [Secrets Management](./SECRETS_MANAGEMENT.md) - Credential management

---

**Last Updated:** February 19, 2026  
**Collection Version:** 2.0.0  
**Supported API Versions:** v1-v9
