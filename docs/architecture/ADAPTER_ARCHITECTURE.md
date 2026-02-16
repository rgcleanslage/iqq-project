# Generic Adapter Architecture

## Overview

Instead of having each provider Lambda contain parsing logic, we now have **generic adapter Lambda functions** that can transform ANY CSV or XML to JSON based purely on DynamoDB configuration.

## Architecture

### Before (Provider-Specific Parsing)
```
┌─────────────────────────┐
│ Client Insurance Lambda │
│ - Calls external API    │
│ - Parses CSV            │ ← Parsing logic in provider
│ - Returns JSON          │
└─────────────────────────┘

┌─────────────────────────┐
│ Route 66 Lambda         │
│ - Calls external API    │
│ - Parses JSON           │ ← Parsing logic in provider
│ - Returns JSON          │
└─────────────────────────┘

┌─────────────────────────┐
│ APCO Lambda             │
│ - Calls external API    │
│ - Parses XML            │ ← Parsing logic in provider
│ - Returns JSON          │
└─────────────────────────┘
```

### After (Generic Adapters)
```
┌─────────────────────────┐
│ Client Insurance Lambda │
│ - Calls external API    │
│ - Returns RAW CSV       │ ← No parsing logic
└─────────────────────────┘
            ↓
┌─────────────────────────┐     ┌──────────┐
│ CSV Adapter Lambda      │ ←── │ DynamoDB │ Mapping Config
│ - Generic CSV parser    │     └──────────┘
│ - Returns JSON          │
└─────────────────────────┘

┌─────────────────────────┐
│ Route 66 Lambda         │
│ - Calls external API    │
│ - Returns RAW JSON      │ ← No parsing logic (pass-through)
└─────────────────────────┘

┌─────────────────────────┐
│ APCO Lambda             │
│ - Calls external API    │
│ - Returns RAW XML       │ ← No parsing logic
└─────────────────────────┘
            ↓
┌─────────────────────────┐     ┌──────────┐
│ XML Adapter Lambda      │ ←── │ DynamoDB │ Mapping Config
│ - Generic XML parser    │     └──────────┘
│ - Returns JSON          │
└─────────────────────────┘
```

## Benefits

### 1. Separation of Concerns
- **Provider Lambdas**: Only responsible for calling external APIs
- **Adapter Lambdas**: Only responsible for format transformation
- **DynamoDB**: Only responsible for configuration storage

### 2. Reusability
- One CSV adapter works for ALL CSV providers
- One XML adapter works for ALL XML providers
- Add new providers without writing parsing code

### 3. Maintainability
- Update parsing logic in one place (adapter)
- Change field mappings without code deployment
- Test adapters independently of providers

### 4. Flexibility
- Support any CSV format via configuration
- Support any XML structure via configuration
- Easy to add new formats (JSON-LD, YAML, etc.)

## Generic Adapter Functions

### CSV Adapter (`iqq-adapter-csv`)

**Input:**
```json
{
  "csvData": "quote_id,premium,coverage_amt\nQ001,1299.99,100000",
  "providerId": "PROV-CLIENT",
  "productId": "PROD-MBP-001"
}
```

**Process:**
1. Reads provider config from DynamoDB
2. Reads mapping config from DynamoDB
3. Parses CSV using `csv-parse`
4. Extracts fields using dot notation paths
5. Applies transformations (parseFloat, parseInt)
6. Returns normalized JSON

**Output:**
```json
{
  "quoteId": "Q001",
  "provider": "Client Insurance",
  "providerId": "PROV-CLIENT",
  "providerRating": "A+",
  "productCode": "MBP",
  "premium": 1299.99,
  "coverageAmount": 100000,
  "termMonths": 60,
  "timestamp": "2026-02-16T19:00:00.000Z"
}
```

### XML Adapter (`iqq-adapter-xml`)

**Input:**
```json
{
  "xmlData": "<?xml version=\"1.0\"?><Quote><ID>Q001</ID><Premium>1299.99</Premium></Quote>",
  "providerId": "PROV-APCO",
  "productId": "PROD-MBP-001"
}
```

**Process:**
1. Reads provider config from DynamoDB
2. Reads mapping config from DynamoDB
3. Parses XML using `fast-xml-parser`
4. Extracts fields using dot notation paths
5. Applies transformations
6. Returns normalized JSON

**Output:**
```json
{
  "quoteId": "Q001",
  "provider": "APCO Insurance",
  "providerId": "PROV-APCO",
  "providerRating": "A-",
  "productCode": "MBP",
  "premium": 1299.99,
  "coverageAmount": 100000,
  "termMonths": 60,
  "timestamp": "2026-02-16T19:00:00.000Z"
}
```

## DynamoDB Configuration

### Provider Configuration
```json
{
  "PK": "PROVIDER#PROV-CLIENT",
  "SK": "METADATA",
  "providerId": "PROV-CLIENT",
  "providerName": "Client Insurance",
  "responseFormat": "CSV",  ← Determines which adapter to use
  "rating": "A+"
}
```

### Mapping Configuration
```json
{
  "PK": "MAPPING#PROD-MBP-001#PROV-CLIENT",
  "SK": "VERSION#1",
  "active": true,
  "mappingConfig": {
    "response": {
      "quoteId": "quote_id",           ← CSV column name
      "premium": "premium",
      "coverageAmount": "coverage_amt",
      "term": "term_months"
    },
    "transformations": {
      "premium": "parseFloat",
      "term": "parseInt"
    }
  }
}
```

## Step Functions Integration

### Updated Workflow
```json
{
  "InvokeProvider": {
    "Type": "Task",
    "Resource": "arn:aws:states:::lambda:invoke",
    "Parameters": {
      "FunctionName": "iqq-provider-client-dev"
    },
    "Next": "CheckFormat"
  },
  "CheckFormat": {
    "Type": "Choice",
    "Choices": [
      {
        "Variable": "$.format",
        "StringEquals": "CSV",
        "Next": "InvokeCSVAdapter"
      },
      {
        "Variable": "$.format",
        "StringEquals": "XML",
        "Next": "InvokeXMLAdapter"
      },
      {
        "Variable": "$.format",
        "StringEquals": "JSON",
        "Next": "PassThrough"
      }
    ]
  },
  "InvokeCSVAdapter": {
    "Type": "Task",
    "Resource": "arn:aws:states:::lambda:invoke",
    "Parameters": {
      "FunctionName": "iqq-adapter-csv-dev",
      "Payload": {
        "csvData.$": "$.body",
        "providerId.$": "$.providerId",
        "productId.$": "$.productId"
      }
    },
    "End": true
  }
}
```

## Adding New Providers

### Example: Add NewCo Insurance (CSV format)

1. **Add provider config to DynamoDB:**
```bash
aws dynamodb put-item --table-name iqq-config-dev --item '{
  "PK": {"S": "PROVIDER#PROV-NEWCO"},
  "SK": {"S": "METADATA"},
  "providerId": {"S": "PROV-NEWCO"},
  "providerName": {"S": "NewCo Insurance"},
  "responseFormat": {"S": "CSV"},
  "rating": {"S": "A"}
}'
```

2. **Add mapping config:**
```bash
aws dynamodb put-item --table-name iqq-config-dev --item '{
  "PK": {"S": "MAPPING#PROD-MBP-001#PROV-NEWCO"},
  "SK": {"S": "VERSION#1"},
  "active": {"BOOL": true},
  "mappingConfig": {"M": {
    "response": {"M": {
      "quoteId": {"S": "id"},
      "premium": {"S": "price"},
      "coverageAmount": {"S": "coverage"},
      "term": {"S": "months"}
    }}
  }}
}'
```

3. **Create provider Lambda** (simple, no parsing logic):
```typescript
export const handler = async (event) => {
  // Call external API
  const csvResponse = await callNewCoAPI(event);
  
  // Return raw CSV
  return {
    statusCode: 200,
    format: 'CSV',
    providerId: 'PROV-NEWCO',
    productId: event.productId,
    body: csvResponse
  };
};
```

4. **Done!** The CSV adapter handles the rest.

## Adding New Formats

To support a new format (e.g., JSON-LD, YAML):

1. Create new adapter Lambda (`iqq-adapter-jsonld`)
2. Implement parsing logic using appropriate library
3. Use same DynamoDB mapping structure
4. Update Step Functions to route to new adapter

## Cost Analysis

**Per Request (3 providers):**
- 3 provider invocations: $0.0000006
- 2 adapter invocations (CSV + XML): $0.0000004
- 6 DynamoDB reads: $0.0000015
- **Total: $0.0000025**

Slightly higher but worth it for the flexibility!

## Files Created

```
iqq-adapter-csv/
├── src/
│   └── index.ts          ← Generic CSV parser
├── package.json
├── tsconfig.json
└── template.yaml

iqq-adapter-xml/
├── src/
│   └── index.ts          ← Generic XML parser
├── package.json
├── tsconfig.json
└── template.yaml

deploy-adapters.sh        ← Deployment script
```

## Next Steps

1. ✅ Create CSV adapter Lambda
2. ✅ Create XML adapter Lambda
3. [ ] Deploy adapters
4. [ ] Update provider Lambdas to return raw formats
5. [ ] Update Step Functions to use adapters
6. [ ] Test end-to-end workflow

---

**Architecture:** Generic Adapters  
**Status:** Ready to Deploy  
**Date:** February 16, 2026

