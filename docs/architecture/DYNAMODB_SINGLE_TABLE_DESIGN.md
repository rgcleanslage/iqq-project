# DynamoDB Single-Table Design - Beginner's Guide

## What is Single-Table Design?

Single-table design is a DynamoDB pattern where you store multiple types of data (entities) in one table instead of creating separate tables for each entity type.

### Traditional Approach (Multiple Tables)
```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Providers      │  │  Clients        │  │  Preferences    │
│  Table          │  │  Table          │  │  Table          │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ provider_id     │  │ client_id       │  │ pref_id         │
│ name            │  │ name            │  │ client_id       │
│ rating          │  │ email           │  │ settings        │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Single-Table Design (Our Approach)
```
┌─────────────────────────────────────────────────────────┐
│  iqq-config (Single Table)                              │
├──────────────────┬──────────────────┬───────────────────┤
│ PK               │ SK               │ Data              │
├──────────────────┼──────────────────┼───────────────────┤
│ PROVIDER#APCO    │ METADATA         │ {name, rating...} │
│ PROVIDER#CLIENT  │ METADATA         │ {name, rating...} │
│ CLIENT#CLI001    │ PREFERENCES      │ {blocked, max...} │
│ CLIENT#CLI002    │ PREFERENCES      │ {allowed...}      │
└──────────────────┴──────────────────┴───────────────────┘
```

## Why Use Single-Table Design?

### 1. Cost Efficiency
**Problem**: Each DynamoDB table has a minimum cost, even if it stores little data.

**Solution**: One table = one set of costs
- ❌ 10 tables × $0.25/month = $2.50/month minimum
- ✅ 1 table × $0.25/month = $0.25/month minimum

### 2. Performance
**Problem**: Joining data across multiple tables requires multiple queries.

**Solution**: Related data can be retrieved in a single query
```javascript
// Multiple tables (slow)
const provider = await getProvider('APCO');        // Query 1
const preferences = await getPreferences('CLI001'); // Query 2
const filtered = filterProviders(provider, preferences); // In-memory

// Single table (fast)
const data = await query({
  PK: 'CLIENT#CLI001',
  SK: { beginsWith: 'PROVIDER#' }
}); // One query gets everything
```

### 3. Atomic Transactions
**Problem**: Updating related data across tables can fail partially.

**Solution**: All related data in one table = atomic updates
```javascript
// Update client preferences and provider status together
await transactWrite([
  { Update: { Key: { PK: 'CLIENT#CLI001', SK: 'PREFERENCES' } } },
  { Update: { Key: { PK: 'PROVIDER#APCO', SK: 'STATUS' } } }
]); // Both succeed or both fail
```

### 4. Simplified Access Patterns
**Problem**: Complex queries across multiple tables.

**Solution**: Design keys to match your access patterns
```javascript
// Access pattern: "Get all preferences for a client"
// Key design: PK = CLIENT#<id>, SK = PREFERENCES
// Result: One query, no joins needed
```

## Our Implementation: iqq-config Table

### Table Structure
```
Table Name: iqq-config-dev
Primary Key: PK (Partition Key)
Sort Key: SK (Sort Key)
```

### Key Design Patterns

#### Pattern 1: Provider Metadata
```
PK: PROVIDER#<providerId>
SK: METADATA

Example:
PK: PROVIDER#APCO
SK: METADATA
Data: {
  name: "APCO Insurance",
  providerId: "PROV-APCO",
  rating: "A-",
  endpoint: "https://apco-api.example.com"
}
```

#### Pattern 2: Client Preferences
```
PK: CLIENT#<clientId>
SK: PREFERENCES

Example:
PK: CLIENT#CLI001
SK: PREFERENCES
Data: {
  clientId: "CLI001",
  clientName: "Premium Auto Dealership",
  allowedProviders: ["Client Direct", "Route66"],
  maxProviders: 2
}
```

## Understanding Keys (PK and SK)

### What are PK and SK?

**PK (Partition Key)**: Determines which physical partition stores the data
- Think of it as a "folder" or "category"
- All items with the same PK are stored together
- Fast to query all items with the same PK

**SK (Sort Key)**: Orders items within a partition
- Think of it as a "filename" within the folder
- Items are sorted by SK within each PK
- Enables range queries (begins_with, between, etc.)

### Visual Example
```
Partition (PK)          Sort Key (SK)           Data
─────────────────────────────────────────────────────────
CLIENT#CLI001     →     PREFERENCES       →     {allowed: ["Client Direct", "Route66"]}
                  →     HISTORY#2026-02   →     {requests: 150}
                  →     HISTORY#2026-01   →     {requests: 120}

CLIENT#CLI002     →     PREFERENCES       →     {allowed: ["APCO"]}
                  →     HISTORY#2026-02   →     {requests: 200}

PROVIDER#APCO     →     METADATA          →     {name: "APCO", rating: "A-"}
                  →     STATS#2026-02     →     {quotes: 500}
```

## Common Query Patterns

### Query 1: Get Client Preferences
**Use Case**: Load preferences for a specific client

```typescript
// Query
const params = {
  TableName: 'iqq-config-dev',
  Key: {
    PK: 'CLIENT#CLI001',
    SK: 'PREFERENCES'
  }
};

const result = await dynamodb.get(params);

// Result
{
  PK: 'CLIENT#CLI001',
  SK: 'PREFERENCES',
  clientId: 'CLI001',
  clientName: 'Premium Auto Dealership',
  allowedProviders: ['Client Direct', 'Route66'],
  maxProviders: 2
}
```

### Query 2: Get All Providers
**Use Case**: List all available providers

```typescript
// Query
const params = {
  TableName: 'iqq-config-dev',
  KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
  ExpressionAttributeValues: {
    ':pk': 'PROVIDER#',
    ':sk': 'METADATA'
  }
};

// Note: This requires a GSI (Global Secondary Index) or scan
// Better approach: Use a specific PK pattern

// Alternative: Query by provider type
const params = {
  TableName: 'iqq-config-dev',
  KeyConditionExpression: 'PK = :pk',
  ExpressionAttributeValues: {
    ':pk': 'PROVIDERS'  // All providers under one PK
  }
};
```

### Query 3: Get All Data for a Client
**Use Case**: Get preferences, history, and stats for a client

```typescript
// Query
const params = {
  TableName: 'iqq-config-dev',
  KeyConditionExpression: 'PK = :pk',
  ExpressionAttributeValues: {
    ':pk': 'CLIENT#CLI001'
  }
};

const result = await dynamodb.query(params);

// Result (multiple items)
[
  { PK: 'CLIENT#CLI001', SK: 'PREFERENCES', allowedProviders: [...] },
  { PK: 'CLIENT#CLI001', SK: 'HISTORY#2026-02', requests: 150 },
  { PK: 'CLIENT#CLI001', SK: 'HISTORY#2026-01', requests: 120 }
]
```

### Query 4: Get Client History for Date Range
**Use Case**: Get client request history for specific months

```typescript
// Query
const params = {
  TableName: 'iqq-config-dev',
  KeyConditionExpression: 'PK = :pk AND SK BETWEEN :start AND :end',
  ExpressionAttributeValues: {
    ':pk': 'CLIENT#CLI001',
    ':start': 'HISTORY#2026-01',
    ':end': 'HISTORY#2026-03'
  }
};

const result = await dynamodb.query(params);

// Result
[
  { PK: 'CLIENT#CLI001', SK: 'HISTORY#2026-01', requests: 120 },
  { PK: 'CLIENT#CLI001', SK: 'HISTORY#2026-02', requests: 150 },
  { PK: 'CLIENT#CLI001', SK: 'HISTORY#2026-03', requests: 180 }
]
```

## Real-World Example: Our Provider Loader

### The Problem
We need to:
1. Get all available providers
2. Get client preferences
3. Filter providers based on preferences

### Traditional Approach (Multiple Tables)
```typescript
// Step 1: Query providers table
const providers = await providersTable.scan();

// Step 2: Query preferences table
const preferences = await preferencesTable.get({
  clientId: 'CLI001'
});

// Step 3: Filter in application code
const filtered = providers.filter(p => 
  preferences.allowedProviders.includes(p.id)
);

// Total: 2 database queries + application filtering
```

### Single-Table Approach (Our Implementation)
```typescript
// Step 1: Get client preferences
const preferences = await dynamodb.get({
  TableName: 'iqq-config-dev',
  Key: {
    PK: 'CLIENT#CLI001',
    SK: 'PREFERENCES'
  }
});

// Step 2: Get all providers (from code, not DB)
const allProviders = ['APCO', 'Client', 'Route66'];

// Step 3: Filter based on preferences
const filtered = allProviders.filter(p => 
  preferences.allowedProviders.includes(p)
);

// Total: 1 database query + application filtering
```

## Code Examples

### Example 1: Seeding Data
```typescript
// Seed provider metadata
await dynamodb.put({
  TableName: 'iqq-config-dev',
  Item: {
    PK: 'PROVIDER#APCO',
    SK: 'METADATA',
    providerId: 'PROV-APCO',
    name: 'APCO Insurance',
    rating: 'A-',
    endpoint: 'https://apco-api.example.com'
  }
});

// Seed client preferences
await dynamodb.put({
  TableName: 'iqq-config-dev',
  Item: {
    PK: 'CLIENT#CLI001',
    SK: 'PREFERENCES',
    clientId: 'CLI001',
    clientName: 'Premium Auto Dealership',
    allowedProviders: ['Client Direct', 'Route66'],
    maxProviders: 2
  }
});
```

### Example 2: Reading Preferences
```typescript
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({ region: 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

async function getClientPreferences(clientId: string) {
  const command = new GetCommand({
    TableName: 'iqq-config-dev',
    Key: {
      PK: `CLIENT#${clientId}`,
      SK: 'PREFERENCES'
    }
  });

  const response = await docClient.send(command);
  return response.Item;
}

// Usage
const prefs = await getClientPreferences('CLI001');
console.log(prefs.allowedProviders); // ['Client Direct', 'Route66']
```

### Example 3: Updating Preferences
```typescript
import { UpdateCommand } from '@aws-sdk/lib-dynamodb';

async function updateClientPreferences(clientId: string, updates: any) {
  const command = new UpdateCommand({
    TableName: 'iqq-config-dev',
    Key: {
      PK: `CLIENT#${clientId}`,
      SK: 'PREFERENCES'
    },
    UpdateExpression: 'SET allowedProviders = :allowed, maxProviders = :max',
    ExpressionAttributeValues: {
      ':allowed': updates.allowedProviders,
      ':max': updates.maxProviders
    },
    ReturnValues: 'ALL_NEW'
  });

  const response = await docClient.send(command);
  return response.Attributes;
}

// Usage
await updateClientPreferences('CLI001', {
  allowedProviders: ['Client Direct'],
  maxProviders: 1
});
```

## Best Practices

### 1. Use Descriptive Prefixes
```typescript
// Good
PK: 'CLIENT#CLI001'
PK: 'PROVIDER#APCO'
PK: 'ORDER#12345'

// Bad
PK: 'CLI001'  // What type is this?
PK: 'APCO'    // Provider or client?
```

### 2. Design Keys for Your Access Patterns
```typescript
// Access pattern: "Get all items for a client"
PK: 'CLIENT#CLI001'
SK: 'PREFERENCES'
SK: 'HISTORY#2026-02'
SK: 'STATS#MONTHLY'

// Access pattern: "Get preferences for a client"
PK: 'CLIENT#CLI001'
SK: 'PREFERENCES'  // Direct access
```

### 3. Use Sort Keys for Hierarchies
```typescript
// Good: Hierarchical sort keys
SK: 'HISTORY#2026#02#15'  // Year-Month-Day
SK: 'CATEGORY#INSURANCE#AUTO'  // Category-Subcategory

// Enables queries like:
// - All history for 2026: SK begins_with 'HISTORY#2026'
// - All history for Feb 2026: SK begins_with 'HISTORY#2026#02'
```

### 4. Keep Related Data Together
```typescript
// Good: Related data under same PK
PK: 'CLIENT#CLI001', SK: 'PREFERENCES'
PK: 'CLIENT#CLI001', SK: 'HISTORY#2026-02'
PK: 'CLIENT#CLI001', SK: 'STATS#MONTHLY'

// Bad: Scattered across different PKs
PK: 'PREFERENCES#CLI001', SK: 'DATA'
PK: 'HISTORY#CLI001', SK: '2026-02'
PK: 'STATS#CLI001', SK: 'MONTHLY'
```

## Common Pitfalls to Avoid

### ❌ Pitfall 1: Using Scan Instead of Query
```typescript
// Bad: Scans entire table
const result = await dynamodb.scan({
  TableName: 'iqq-config-dev',
  FilterExpression: 'clientId = :id',
  ExpressionAttributeValues: { ':id': 'CLI001' }
});

// Good: Queries specific partition
const result = await dynamodb.query({
  TableName: 'iqq-config-dev',
  KeyConditionExpression: 'PK = :pk',
  ExpressionAttributeValues: { ':pk': 'CLIENT#CLI001' }
});
```

### ❌ Pitfall 2: Not Using Prefixes
```typescript
// Bad: Can't distinguish entity types
PK: 'CLI001'
PK: 'APCO'

// Good: Clear entity types
PK: 'CLIENT#CLI001'
PK: 'PROVIDER#APCO'
```

### ❌ Pitfall 3: Overloading Sort Keys
```typescript
// Bad: Too much data in SK
SK: 'PREF#BLOCKED:APCO,Route66#MAX:2#ALLOWED:Client'

// Good: Use attributes for data
SK: 'PREFERENCES'
Attributes: {
  allowedProviders: ['Client Direct', 'Route66'],
  maxProviders: 2,
  preferredProviders: ['Client Direct']
}
```

## When NOT to Use Single-Table Design

### 1. Simple Applications
If you only have 1-2 entity types with no relationships, multiple tables might be simpler.

### 2. Frequently Changing Access Patterns
If your access patterns change often, single-table design requires more refactoring.

### 3. Team Unfamiliarity
If your team is new to DynamoDB, start with multiple tables and migrate later.

### 4. Heavy Relational Queries
If you need complex joins and aggregations, consider using RDS instead.

## Summary

### Key Takeaways
1. **Single-table design** = Multiple entity types in one table
2. **PK** = Partition key (category/folder)
3. **SK** = Sort key (identifier within partition)
4. **Benefits**: Lower cost, better performance, atomic transactions
5. **Design keys** to match your access patterns

### Our Implementation
- **Table**: `iqq-config-dev`
- **Entities**: Providers, Client Preferences
- **Pattern**: `PK: ENTITY#ID`, `SK: TYPE`
- **Queries**: 1 query to get client preferences, filter providers in code

## Further Reading

- [AWS DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [The DynamoDB Book by Alex DeBrie](https://www.dynamodbbook.com/)
- [Rick Houlihan's re:Invent Talks](https://www.youtube.com/results?search_query=rick+houlihan+dynamodb)

## Date Created
February 18, 2026

## Last Updated
February 18, 2026
