# Client Preferences Guide

Complete guide to managing client-specific preferences for provider filtering and customization.

## Overview

The client preferences system allows you to store and apply client-specific settings that control which insurance providers are queried and how quotes are aggregated. This is stored in the same DynamoDB table using single-table design principles.

## Table Structure

Preferences are stored in the `iqq-config` table with the following access patterns:

```
PK: CLIENT#<clientId>
SK: PREFERENCES
GSI1PK: PREFERENCES
GSI1SK: CLIENT#<clientId>
```

## Preference Types

### 1. Provider Restrictions

#### Blocked Providers (Blacklist)
Exclude specific providers from being queried.

```typescript
{
  clientId: "CLI001",
  blockedProviders: ["PROV-APCO", "PROV-ROUTE66"]
}
```

**Use case:** Client has had bad experience with a provider or provider doesn't meet client's requirements.

#### Allowed Providers (Whitelist)
Only query specific providers (all others are excluded).

```typescript
{
  clientId: "CLI002",
  allowedProviders: ["PROV-CLIENT", "PROV-ROUTE66"]
}
```

**Use case:** Client has exclusive agreements with certain providers.

**Priority:** `blockedProviders` is applied first, then `allowedProviders` filters the remaining providers.

### 2. Provider Preferences

#### Preferred Providers
Specify the order in which providers should be prioritized.

```typescript
{
  clientId: "CLI003",
  preferredProviders: ["PROV-CLIENT", "PROV-APCO"]
}
```

**Use case:** Client prefers certain providers due to better rates or service quality.

**Behavior:** Preferred providers appear first in the results, maintaining their specified order.

#### Maximum Providers
Limit the number of providers to query.

```typescript
{
  clientId: "CLI004",
  maxProviders: 2
}
```

**Use case:** Reduce API costs or response time by limiting provider queries.

**Behavior:** Applied after filtering and sorting, returns only the first N providers.

### 3. Future Preferences (Extensible)

The system is designed to support additional preferences:

- `minProviderRating`: Only query providers with rating >= threshold
- `preferredResponseFormat`: Prefer JSON over CSV/XML
- `timeout`: Custom timeout per client
- `cacheEnabled`: Enable/disable quote caching
- `notificationEmail`: Email for quote notifications

## Managing Preferences

### Using the CLI Script

#### Set Preferences

```bash
# Block specific providers
ts-node scripts/manage-client-preferences.ts set CLI001 --blocked PROV-APCO

# Allow only specific providers
ts-node scripts/manage-client-preferences.ts set CLI002 --allowed PROV-CLIENT,PROV-ROUTE66

# Set preferred providers
ts-node scripts/manage-client-preferences.ts set CLI003 --preferred PROV-CLIENT,PROV-APCO

# Limit number of providers
ts-node scripts/manage-client-preferences.ts set CLI004 --max 2

# Combine multiple preferences
ts-node scripts/manage-client-preferences.ts set CLI001 \
  --blocked PROV-APCO \
  --preferred PROV-CLIENT \
  --max 2
```

#### Get Preferences

```bash
ts-node scripts/manage-client-preferences.ts get CLI001
```

#### Delete Preferences

```bash
ts-node scripts/manage-client-preferences.ts delete CLI001
```

### Using AWS CLI

#### Put Preferences

```bash
aws dynamodb put-item \
  --table-name iqq-config-dev \
  --item '{
    "PK": {"S": "CLIENT#CLI001"},
    "SK": {"S": "PREFERENCES"},
    "GSI1PK": {"S": "PREFERENCES"},
    "GSI1SK": {"S": "CLIENT#CLI001"},
    "clientId": {"S": "CLI001"},
    "blockedProviders": {"L": [{"S": "PROV-APCO"}]},
    "maxProviders": {"N": "2"},
    "updatedAt": {"S": "2026-02-18T10:00:00Z"}
  }'
```

#### Get Preferences

```bash
aws dynamodb get-item \
  --table-name iqq-config-dev \
  --key '{
    "PK": {"S": "CLIENT#CLI001"},
    "SK": {"S": "PREFERENCES"}
  }'
```

## Using Preferences in API Calls

### Package Service with Client ID

Add the `clientId` query parameter to apply preferences:

```bash
# Without preferences (all active providers)
curl -X GET "https://api.example.com/dev/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# With preferences (filtered providers)
curl -X GET "https://api.example.com/dev/package?productCode=MBP&clientId=CLI001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### Response Differences

**Without clientId:**
```json
{
  "providerQuotes": [
    {"provider": "Client Insurance", "premium": 1250.00},
    {"provider": "Route 66 Insurance", "premium": 1180.00},
    {"provider": "APCO Insurance", "premium": 1320.00}
  ],
  "summary": {
    "totalQuotes": 3
  }
}
```

**With clientId=CLI001 (blocked APCO, max 2):**
```json
{
  "providerQuotes": [
    {"provider": "Client Insurance", "premium": 1250.00},
    {"provider": "Route 66 Insurance", "premium": 1180.00}
  ],
  "summary": {
    "totalQuotes": 2
  }
}
```

## Implementation Flow

```
┌─────────────────┐
│ Package Service │
│  (clientId)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Step Functions  │
│  (pass clientId)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Provider Loader │
│  1. Load all    │
│     active      │
│     providers   │
│  2. Load client │
│     preferences │
│  3. Apply       │
│     filters     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Filtered        │
│ Provider List   │
└─────────────────┘
```

## Filter Priority

Filters are applied in this order:

1. **Load all active providers** from DynamoDB (GSI2)
2. **Apply blockedProviders** (remove from list)
3. **Apply allowedProviders** (keep only these)
4. **Sort by preferredProviders** (reorder list)
5. **Apply maxProviders** (limit list size)

## Example Scenarios

### Scenario 1: Exclusive Provider Agreement

**Requirement:** CLI002 only works with Client Insurance and Route 66.

**Configuration:**
```typescript
{
  clientId: "CLI002",
  allowedProviders: ["PROV-CLIENT", "PROV-ROUTE66"]
}
```

**Result:** Only these two providers are queried, APCO is excluded.

### Scenario 2: Provider Blacklist

**Requirement:** CLI001 had issues with APCO and doesn't want their quotes.

**Configuration:**
```typescript
{
  clientId: "CLI001",
  blockedProviders: ["PROV-APCO"]
}
```

**Result:** All providers except APCO are queried.

### Scenario 3: Cost Optimization

**Requirement:** CLI004 wants to reduce API costs by limiting to 2 providers.

**Configuration:**
```typescript
{
  clientId: "CLI004",
  maxProviders: 2,
  preferredProviders: ["PROV-CLIENT", "PROV-ROUTE66"]
}
```

**Result:** Only Client Insurance and Route 66 are queried (in that order).

### Scenario 4: Complex Preferences

**Requirement:** CLI003 wants Client Insurance first, max 2 providers, but never APCO.

**Configuration:**
```typescript
{
  clientId: "CLI003",
  blockedProviders: ["PROV-APCO"],
  preferredProviders: ["PROV-CLIENT"],
  maxProviders: 2
}
```

**Result:** Client Insurance first, then Route 66 (APCO blocked, limited to 2).

## Monitoring and Logging

The provider-loader Lambda logs preference application:

```json
{
  "message": "Applying client preferences",
  "clientId": "CLI001",
  "preferences": {
    "blockedProviders": ["PROV-APCO"],
    "maxProviders": 2
  }
}
```

```json
{
  "message": "After filtering: 2 providers",
  "providerIds": ["PROV-CLIENT", "PROV-ROUTE66"]
}
```

## Testing

### Test Without Preferences

```bash
curl -X GET "https://api.example.com/dev/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

Expected: All 3 providers return quotes.

### Test With Preferences

```bash
# Set preferences
ts-node scripts/manage-client-preferences.ts set CLI001 --blocked PROV-APCO

# Test API
curl -X GET "https://api.example.com/dev/package?productCode=MBP&clientId=CLI001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

Expected: Only 2 providers return quotes (APCO excluded).

## Best Practices

1. **Use allowedProviders for strict control** - When client has exclusive agreements
2. **Use blockedProviders for exceptions** - When most providers are acceptable
3. **Combine with maxProviders** - To control costs and response time
4. **Set preferredProviders** - To ensure best providers are queried first
5. **Document client preferences** - Keep track of why preferences were set
6. **Test after changes** - Verify preferences work as expected
7. **Monitor logs** - Check CloudWatch for preference application

## Security Considerations

- Preferences are stored in DynamoDB with encryption at rest
- Only Lambda functions with proper IAM roles can read preferences
- Client ID should be validated before applying preferences
- Consider adding audit logging for preference changes

## Future Enhancements

Potential additions to the preference system:

- **Time-based preferences** - Different preferences for different times
- **Product-specific preferences** - Different providers per product type
- **Dynamic pricing rules** - Custom markup/discount per client
- **SLA requirements** - Minimum response time or availability
- **Compliance requirements** - Provider must meet certain standards

---

**Last Updated:** February 18, 2026  
**Version:** 1.0.0
