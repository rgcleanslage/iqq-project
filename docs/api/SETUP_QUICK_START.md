# Quick Start Guide - API Testing Setup

## Overview
This guide helps you quickly set up Postman for testing the iQQ API with automatic client ID mapping.

## Prerequisites
- Postman installed
- Access to the repository
- Terraform applied in `iqq-infrastructure/`

## 5-Minute Setup

### Step 1: Generate Environment Files (1 min)
```bash
# From repository root
./scripts/generate-postman-environments.sh
```

This creates three environment files with your credentials:
- `docs/api/postman-environment-default.json` (CLI001)
- `docs/api/postman-environment-partner-a.json` (CLI002)
- `docs/api/postman-environment-partner-b.json` (CLI003)

### Step 2: Import into Postman (2 min)
1. Open Postman
2. Click "Import" button (top left)
3. Drag and drop these files:
   - `docs/api/postman-collection-fixed.json` (the collection)
   - `docs/api/postman-environment-default.json`
   - `docs/api/postman-environment-partner-a.json`
   - `docs/api/postman-environment-partner-b.json`
4. Click "Import"

### Step 3: Select Environment (30 sec)
1. Click environment dropdown (top right)
2. Select "iQQ Default Client (CLI001)"

### Step 4: Get OAuth Token (30 sec)
1. In collection, expand "Authentication" folder
2. Click "Get OAuth Token (Working)"
3. Click "Send"
4. Token is automatically saved

### Step 5: Test API (1 min)
1. Expand "Package" folder
2. Click "Get Package (Default Client - CLI001)"
3. Click "Send"
4. Verify response:
   - Should return 2 quotes
   - APCO Insurance should be blocked
   - Only Client Direct and Route66 returned

## Testing Different Clients

### CLI001 (Default Client)
- Environment: "iQQ Default Client (CLI001)"
- Preferences: Blocks APCO, max 2 providers
- Expected: 2 quotes

### CLI002 (Partner A)
- Environment: "iQQ Partner A Client (CLI002)"
- Preferences: Only allows Client Direct and Route66
- Expected: 2 quotes

### CLI003 (Partner B)
- Environment: "iQQ Partner B Client (CLI003)"
- Preferences: None
- Expected: 3 quotes (all providers)

## How It Works

### Automatic Client ID Mapping
1. You select an environment (e.g., CLI001)
2. Get OAuth token using that client's credentials
3. Send request with that client's API key
4. API automatically extracts client ID from API key tags
5. API validates API key's client ID matches OAuth token
6. Client preferences are automatically applied

### No Manual Client ID Required
- Old way: `?clientId=CLI001` (manual, can be spoofed)
- New way: Automatic extraction from API key tags (secure)

## Troubleshooting

### "Unauthorized" (401)
**Solution**: Run "Get OAuth Token (Working)" again

### "Forbidden" (403) - "Client ID mismatch"
**Solution**: Ensure you're using the correct environment (OAuth credentials and API key must match)

### "Forbidden" (403) - "Invalid API key"
**Solution**: Regenerate environment files: `./scripts/generate-postman-environments.sh`

### Wrong number of quotes
**Solution**: Verify correct environment is selected

## Advanced Testing

### Test Client ID Mismatch (Security Validation)
1. Select "iQQ Default Client (CLI001)"
2. Get OAuth Token
3. In environment, manually change `apiKey` to Partner A's key
4. Send Package request
5. Should receive 403 Forbidden

### Test All Clients Quickly
```bash
# Generate test scripts
./scripts/generate-test-scripts.sh

# Run comprehensive tests
./scripts/test-complete-client-mapping.sh
```

## Security Notes

⚠️ **Important**: Generated environment files contain secrets and are excluded from git.

- Don't commit `postman-environment-*.json` files
- Regenerate files if credentials are rotated
- Use different credentials for production

## Next Steps

- [POSTMAN_CLIENT_SETUP.md](POSTMAN_CLIENT_SETUP.md) - Detailed setup guide
- [CLIENT_CREDENTIALS_MAPPING.md](CLIENT_CREDENTIALS_MAPPING.md) - Credential reference
- [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md) - Security best practices
- [API_DOCUMENTATION_COMPLETE.md](API_DOCUMENTATION_COMPLETE.md) - Full API docs

## Support

If you encounter issues:
1. Check [POSTMAN_TROUBLESHOOTING.md](POSTMAN_TROUBLESHOOTING.md)
2. Verify Terraform is applied: `cd iqq-infrastructure && terraform plan`
3. Regenerate files: `./scripts/generate-postman-environments.sh`
4. Check CloudWatch logs: `aws logs tail /aws/lambda/iqq-package-service-dev --since 5m --region us-east-1`

## Date Created
February 18, 2026
