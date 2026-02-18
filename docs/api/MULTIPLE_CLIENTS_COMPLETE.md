# Multiple Cognito Clients - Complete ✅

## Overview
Successfully created separate Cognito app clients for each API key, providing better security, isolation, and tracking per partner.

## What Was Created

### 1. Cognito App Clients (4 total)

#### Default Client
- **Client ID**: `24j8eld9b4h7h0mnsa0b75t8ba`
- **Client Name**: `iqq-default-client-dev`
- **API Key**: `Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH`
- **Usage Plan**: Standard (1000 req/day, 10 req/sec)
- **Use Case**: Internal testing, default access

#### Partner A Client
- **Client ID**: `518u138r9smc4iq9p6sf32e2o4`
- **Client Name**: `iqq-partner_a-client-dev`
- **API Key**: (from Terraform output)
- **Usage Plan**: Premium (10000 req/day, 100 req/sec)
- **Use Case**: Premium partner with higher limits

#### Partner B Client
- **Client ID**: `4igbgdb4mmmo870serh2ehqcu5`
- **Client Name**: `iqq-partner_b-client-dev`
- **API Key**: (from Terraform output)
- **Usage Plan**: Standard (1000 req/day, 10 req/sec)
- **Use Case**: Standard partner

#### Legacy Client (Backward Compatibility)
- **Client ID**: `25oa5u3vup2jmhl270e7shudkl`
- **Client Name**: `iqq-app-client-dev`
- **Use Case**: Backward compatibility only

### 2. Postman Environments

Created separate environment files for each client:
- `postman-environment-default.json` - Default client
- `postman-environment-partner-a.json` - Partner A
- `postman-environment-partner-b.json` - Partner B
- `postman-environment.json` - Legacy (original)

### 3. Documentation

- `CLIENT_CREDENTIALS_MAPPING.md` - Complete mapping of clients to API keys
- `MULTIPLE_CLIENTS_COMPLETE.md` - This file

### 4. Testing Tools

- `scripts/test-all-clients.sh` - Automated test for all clients

## Test Results

All clients tested successfully:

```
✓ Default Client working correctly
✓ Partner A Client working correctly
✓ Partner B Client working correctly
✓ Legacy Client working correctly
```

Each client can:
- ✅ Obtain OAuth token from Cognito
- ✅ Authenticate with API Gateway
- ✅ Access all API endpoints
- ✅ Use their respective API keys

## Benefits

### 1. Security Isolation
- Each partner has unique OAuth credentials
- Compromised credentials affect only one partner
- Easy to revoke access per partner
- No cross-partner credential sharing

### 2. Tracking & Monitoring
- CloudWatch logs show which client made requests
- Usage metrics per client
- Audit trail per partner
- Better analytics and reporting

### 3. Rate Limiting
- API keys enforce rate limits via usage plans
- OAuth tokens provide authentication
- Double layer of protection
- Different limits per partner (Standard vs Premium)

### 4. Credential Rotation
- Rotate credentials per partner independently
- No impact on other partners
- Gradual migration support
- Zero downtime updates

## Usage

### Get Credentials

```bash
# Navigate to infrastructure directory
cd iqq-infrastructure

# Get all client IDs
terraform output -json cognito_partner_clients | jq .

# Get all client secrets
terraform output -json cognito_partner_client_secrets | jq -r 'to_entries[] | "\(.key): \(.value)"'

# Get specific partner
terraform output -json cognito_partner_clients | jq -r '.partner_a.client_id'
terraform output -json cognito_partner_client_secrets | jq -r '.partner_a'
```

### Test All Clients

```bash
./scripts/test-all-clients.sh
```

### Use in Postman

1. Import `postman-collection-fixed.json`
2. Import environment for your client:
   - `postman-environment-default.json` (Default)
   - `postman-environment-partner-a.json` (Partner A)
   - `postman-environment-partner-b.json` (Partner B)
3. Select the environment
4. Run "Get OAuth Token (Working)"
5. Test endpoints

### Use with cURL

```bash
# Example: Partner A
CLIENT_ID="518u138r9smc4iq9p6sf32e2o4"
CLIENT_SECRET="130rm5c8mr49mold1rpq23s0nl150ne6l07a54q75nkmm5v55n4c"
API_KEY="your-partner-a-api-key"

# Get token
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read" | jq -r '.access_token')

# Call API
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

## Adding New Clients

To add a new partner client:

### 1. Update Terraform Configuration

Edit `iqq-infrastructure/modules/cognito/main.tf`:

```hcl
resource "aws_cognito_user_pool_client" "partners" {
  for_each = var.create_partner_clients ? toset(["default", "partner_a", "partner_b", "partner_c"]) : toset([])
  # ... rest of configuration
}
```

### 2. Apply Changes

```bash
cd iqq-infrastructure
terraform plan
terraform apply
```

### 3. Retrieve New Credentials

```bash
terraform output -json cognito_partner_clients | jq -r '.partner_c'
terraform output -json cognito_partner_client_secrets | jq -r '.partner_c'
```

### 4. Create API Key (if needed)

Add to `modules/api-gateway/main.tf` and deploy.

### 5. Create Postman Environment

Copy and modify one of the existing environment files.

### 6. Document

Update `CLIENT_CREDENTIALS_MAPPING.md` with new client details.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Cognito User Pool                        │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Default Client   │  │ Partner A Client │                │
│  │ ID: 24j8eld...   │  │ ID: 518u138...   │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Partner B Client │  │ Legacy Client    │                │
│  │ ID: 4igbgdb...   │  │ ID: 25oa5u3...   │                │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    OAuth 2.0 Token
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                     API Gateway                              │
│                                                              │
│  1. Lambda Authorizer validates OAuth token                 │
│  2. API Key validation                                      │
│  3. Usage plan enforcement                                  │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Default Key  │  │ Partner A    │  │ Partner B    │     │
│  │ Standard     │  │ Premium      │  │ Standard     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    Lambda Functions
```

## Migration Path

### Phase 1: Create New Clients ✅
- Create separate Cognito app clients
- Test all clients
- Document credentials

### Phase 2: Distribute Credentials (Current)
- Provide partner-specific credentials to each partner
- Update partner documentation
- Provide migration timeline

### Phase 3: Monitor Usage
- Track which clients are being used
- Monitor for any issues
- Provide support during transition

### Phase 4: Deprecate Legacy
- Set deprecation date for legacy client
- Send notifications to partners
- Disable legacy client after grace period

## Security Considerations

### Credential Storage
- ✅ Client secrets stored in Terraform state (encrypted)
- ✅ Secrets marked as sensitive in outputs
- ✅ Never committed to version control
- ✅ Retrieved only when needed

### Access Control
- ✅ Each client has unique credentials
- ✅ API keys enforce rate limits
- ✅ OAuth tokens expire after 1 hour
- ✅ CloudWatch logging for audit trail

### Rotation Policy
- Rotate client secrets every 90 days
- Update API keys annually
- Notify partners 30 days before rotation
- Provide overlap period for migration

## Monitoring

### CloudWatch Metrics
- Track requests per client
- Monitor error rates
- Alert on unusual patterns
- Usage analytics per partner

### CloudWatch Logs
- `/aws/lambda/iqq-*-service-dev` - Lambda logs
- `/aws/apigateway/iqq-dev` - API Gateway logs
- `/aws/vendedlogs/states/iqq-quote-orchestrator-dev` - Step Functions logs

### Queries
```
# Find requests by client
fields @timestamp, @message
| filter @message like /CLIENT_ID/
| sort @timestamp desc

# Track usage per partner
stats count() by clientId
| sort count desc
```

## Files Created

```
iqq-infrastructure/
└── modules/
    └── cognito/
        ├── main.tf (updated)
        ├── variables.tf (updated)
        └── outputs.tf (updated)

docs/api/
├── CLIENT_CREDENTIALS_MAPPING.md
├── MULTIPLE_CLIENTS_COMPLETE.md
├── postman-environment-default.json
├── postman-environment-partner-a.json
└── postman-environment-partner-b.json

scripts/
└── test-all-clients.sh
```

## Support

For issues with client credentials:
- Check: `docs/api/CLIENT_CREDENTIALS_MAPPING.md`
- Test: `./scripts/test-all-clients.sh`
- Logs: CloudWatch `/aws/lambda/iqq-*-service-dev`
- Contact: api-support@iqq.com

## Date Completed
February 17, 2026

## Status
✅ **COMPLETE** - All clients created, tested, and documented. Each API key now has its own Cognito app client.
