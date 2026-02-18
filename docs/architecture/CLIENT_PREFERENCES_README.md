# Client Preferences System

A flexible, extensible system for storing and applying client-specific preferences using DynamoDB single-table design.

## Quick Start

### 1. Seed Sample Preferences

```bash
cd scripts
ts-node seed-dynamodb.ts
```

This creates two sample clients with preferences:
- **CLI001**: Blocks APCO, prefers Client Insurance, max 2 providers
- **CLI002**: Only allows Client Insurance and Route 66

### 2. Test the System

```bash
./scripts/test-client-preferences.sh
```

### 3. Manage Preferences

```bash
# Block a provider
ts-node scripts/manage-client-preferences.ts set CLI001 --blocked PROV-APCO

# Allow only specific providers
ts-node scripts/manage-client-preferences.ts set CLI002 --allowed PROV-CLIENT,PROV-ROUTE66

# Set preferred order and limit
ts-node scripts/manage-client-preferences.ts set CLI003 --preferred PROV-CLIENT --max 2

# View preferences
ts-node scripts/manage-client-preferences.ts get CLI001

# Delete preferences
ts-node scripts/manage-client-preferences.ts delete CLI001
```

## Features

### Provider Filtering

- **Blocked Providers**: Exclude specific providers from queries
- **Allowed Providers**: Whitelist only certain providers
- **Preferred Providers**: Control the order providers are queried
- **Max Providers**: Limit the number of providers to reduce costs

### Extensible Design

The system supports adding new preference types:
- Minimum provider rating
- Custom timeouts
- Notification settings
- Product-specific rules
- And more...

## API Usage

### Without Preferences (All Providers)

```bash
curl -X GET "${API_URL}/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

Returns quotes from all 3 active providers.

### With Preferences (Filtered Providers)

```bash
curl -X GET "${API_URL}/package?productCode=MBP&clientId=CLI001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

Returns quotes based on CLI001's preferences (e.g., APCO blocked, max 2 providers).

## Architecture

```
Package Service
    ↓ (passes clientId)
Step Functions
    ↓
Provider Loader
    ├─ Load all active providers
    ├─ Load client preferences (if clientId provided)
    ├─ Apply filters:
    │   1. Block providers (blockedProviders)
    │   2. Allow only specific (allowedProviders)
    │   3. Sort by preference (preferredProviders)
    │   4. Limit count (maxProviders)
    └─ Return filtered list
```

## Data Model (Single Table Design)

```
Table: iqq-config-dev

PK: CLIENT#<clientId>
SK: PREFERENCES
GSI1PK: PREFERENCES
GSI1SK: CLIENT#<clientId>

Attributes:
- clientId: string
- allowedProviders: string[]
- blockedProviders: string[]
- preferredProviders: string[]
- maxProviders: number
- createdAt: ISO timestamp
- updatedAt: ISO timestamp
```

## Example Preferences

### Block Specific Provider

```json
{
  "clientId": "CLI001",
  "blockedProviders": ["PROV-APCO"]
}
```

### Whitelist Providers

```json
{
  "clientId": "CLI002",
  "allowedProviders": ["PROV-CLIENT", "PROV-ROUTE66"]
}
```

### Complex Preferences

```json
{
  "clientId": "CLI003",
  "blockedProviders": ["PROV-APCO"],
  "preferredProviders": ["PROV-CLIENT"],
  "maxProviders": 2
}
```

## Deployment

### 1. Deploy Provider Loader

```bash
cd iqq-providers
npm run build
sam build
sam deploy
```

### 2. Deploy Package Service

```bash
cd iqq-package-service
npm run build
sam build
sam deploy
```

### 3. Seed Preferences

```bash
ts-node scripts/seed-dynamodb.ts
```

### 4. Test

```bash
./scripts/test-client-preferences.sh
```

## Documentation

- **[Complete Guide](CLIENT_PREFERENCES_GUIDE.md)** - Detailed documentation
- **[Architecture Diagram](SYSTEM_ARCHITECTURE_DIAGRAM.md)** - System overview
- **[API Documentation](../api/API_DOCUMENTATION_COMPLETE.md)** - API reference

## Use Cases

1. **Exclusive Agreements** - Client only works with specific providers
2. **Provider Blacklist** - Client had issues with a provider
3. **Cost Optimization** - Limit providers to reduce API costs
4. **Performance** - Reduce response time by querying fewer providers
5. **Compliance** - Only use providers that meet certain standards

## Monitoring

Check CloudWatch logs for preference application:

```bash
aws logs tail /aws/lambda/iqq-provider-loader-dev --follow
```

Look for log entries:
- "Applying client preferences"
- "After filtering: N providers"
- "Blocked providers: ..."
- "Allowed providers only: ..."

## Testing

Run the test suite:

```bash
./scripts/test-client-preferences.sh
```

Expected results:
- ✅ Test 1: 3 quotes (no preferences)
- ✅ Test 2: 2 quotes (CLI001 - APCO blocked)
- ✅ Test 3: 2 quotes (CLI002 - only allowed)
- ✅ Test 4: 3 quotes (non-existent client)

## Troubleshooting

### Preferences Not Applied

1. Check clientId is passed in API request
2. Verify preferences exist in DynamoDB
3. Check CloudWatch logs for errors
4. Ensure provider-loader has DynamoDB permissions

### Wrong Providers Returned

1. Verify preference configuration
2. Check filter priority (blocked → allowed → preferred → max)
3. Review CloudWatch logs for filter application

### Performance Issues

1. Consider using maxProviders to limit queries
2. Check DynamoDB read capacity
3. Monitor Lambda execution time

---

**Last Updated:** February 18, 2026  
**Version:** 1.0.0
