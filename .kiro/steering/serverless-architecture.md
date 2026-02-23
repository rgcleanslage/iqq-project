---
inclusion: auto
description: Serverless architecture patterns including Lambda standards, Step Functions orchestration, DynamoDB design, and SAM deployment practices
---

# Serverless Architecture Patterns

This project uses AWS serverless architecture with specific patterns and conventions.

## Lambda Function Standards

### Runtime & Architecture
- Runtime: Node.js 20.x
- Architecture: ARM64 (20% cost savings vs x86)
- Memory: 512MB (right-sized for most functions)
- Timeout: 30 seconds (API functions), 60 seconds (orchestration)

### TypeScript Build Process
**CRITICAL**: Lambda functions require pre-compiled TypeScript code.

1. Build TypeScript locally first:
   ```bash
   npm run build
   ```

2. SAM copies the compiled `dist/` folder using Makefiles:
   ```makefile
   build-FunctionName:
       cp -r dist $(ARTIFACTS_DIR)/
       cp package.json $(ARTIFACTS_DIR)/
       cd $(ARTIFACTS_DIR) && npm install --production
   ```

3. SAM template uses `BuildMethod: makefile`:
   ```yaml
   Metadata:
     BuildMethod: makefile
   ```

**Never** use `BuildMethod: esbuild` or rely on SAM to compile TypeScript. Always pre-build locally.

### Function Structure
```typescript
// src/index.ts
export const handler = async (event: any) => {
  // Extract correlation ID
  const correlationId = event.requestContext?.requestId || 'unknown';
  
  // Structured logging
  console.log(JSON.stringify({
    level: 'INFO',
    message: 'Processing request',
    correlationId,
    event
  }));
  
  try {
    // Business logic
    const result = await processRequest(event);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'X-Correlation-ID': correlationId
      },
      body: JSON.stringify(result)
    };
  } catch (error) {
    console.error(JSON.stringify({
      level: 'ERROR',
      message: 'Request failed',
      correlationId,
      error: error.message,
      stack: error.stack
    }));
    
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};
```

## Step Functions Orchestration

### State Machine Type
- Use **EXPRESS** state machines for synchronous API responses
- Execution time: < 5 minutes
- Cost: ~$1 per million executions

### Invocation Pattern
```typescript
import { SFNClient, StartSyncExecutionCommand } from '@aws-sdk/client-sfn';

const sfnClient = new SFNClient({ region: 'us-east-1' });

const command = new StartSyncExecutionCommand({
  stateMachineArn: process.env.STATE_MACHINE_ARN,
  input: JSON.stringify(inputData)
});

const response = await sfnClient.send(command);
const output = JSON.parse(response.output);
```

### Map State for Parallel Processing
```json
{
  "Type": "Map",
  "ItemsPath": "$.providers",
  "MaxConcurrency": 10,
  "ResultPath": "$.results",
  "Iterator": {
    "StartAt": "ProcessItem",
    "States": { ... }
  }
}
```

### Error Handling
Always include retry logic and catch blocks:
```json
{
  "Retry": [{
    "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
    "IntervalSeconds": 2,
    "MaxAttempts": 3,
    "BackoffRate": 2
  }],
  "Catch": [{
    "ErrorEquals": ["States.ALL"],
    "ResultPath": "$.error",
    "Next": "HandleError"
  }]
}
```

## DynamoDB Single-Table Design

### Table Structure
- Table: `iqq-config-{environment}`
- Primary Key: `PK` (partition), `SK` (sort)
- GSI1: Entity type queries (`GSI1PK`, `GSI1SK`)
- GSI2: Status-based queries (`GSI2PK`, `GSI2SK`)

### Access Patterns
```typescript
// Query active providers using GSI2
const command = new QueryCommand({
  TableName: TABLE_NAME,
  IndexName: 'GSI2',
  KeyConditionExpression: 'GSI2PK = :pk AND begins_with(GSI2SK, :provider)',
  ExpressionAttributeValues: {
    ':pk': 'STATUS#ACTIVE',
    ':provider': 'PROVIDER#'
  }
});
```

### Key Patterns
- Clients: `PK=CLIENT#{id}`, `SK=METADATA`
- Products: `PK=PRODUCT#{code}`, `SK=METADATA`
- Providers: `PK=PROVIDER#{id}`, `SK=METADATA`
- Mappings: `PK=MAPPING#{provider}`, `SK=FIELD#{name}`

## SAM Deployment

### Project Structure
```
service/
├── src/
│   └── index.ts
├── dist/              ← Compiled output
├── tests/
├── events/
│   └── test-event.json
├── Makefile           ← Build instructions
├── template.yaml      ← SAM template
├── samconfig.toml     ← Deployment config
├── package.json
└── tsconfig.json
```

### Deployment Commands
```bash
# Build TypeScript
npm run build

# Build SAM package
sam build

# Deploy
sam deploy

# Deploy with parameters
sam deploy --parameter-overrides Environment=dev
```

### Local Testing
```bash
# Invoke function locally
sam local invoke FunctionName -e events/test-event.json

# With environment variables
sam local invoke FunctionName -e events/test-event.json --env-vars env.json
```

## Monitoring & Logging

### Structured Logging
Always use JSON format with these fields:
- `level`: INFO, WARN, ERROR
- `message`: Human-readable message
- `correlationId`: Request tracking ID
- `timestamp`: ISO 8601 format
- Additional context fields

### X-Ray Tracing
Enable in SAM template:
```yaml
Tracing: Active
Environment:
  Variables:
    AWS_XRAY_TRACING_NAME: service-name
```

### CloudWatch Metrics
- Lambda invocations, errors, duration
- Step Functions executions, failures
- DynamoDB read/write capacity
- API Gateway requests, latency

## Cost Optimization

1. **ARM64 Architecture**: 20% cheaper than x86
2. **Right-sized Memory**: 512MB for most functions
3. **Short Log Retention**: 7 days (not 30)
4. **On-demand Pricing**: DynamoDB, no reserved capacity
5. **EXPRESS State Machines**: Cheaper than STANDARD

## Security Best Practices

1. **Least Privilege IAM**: Only required permissions
2. **Environment Variables**: Never hardcode secrets
3. **Encryption**: At rest (DynamoDB) and in transit (HTTPS)
4. **Input Validation**: Always validate and sanitize
5. **Error Messages**: Don't expose internal details

## Common Patterns

### Adapter Pattern
Generic adapters for data transformation:
- CSV Adapter: Converts CSV to JSON using DynamoDB mappings
- XML Adapter: Converts XML to JSON using DynamoDB mappings
- Configuration-driven, no code changes for new providers

### Dynamic Provider Loading
Providers stored in DynamoDB, loaded at runtime:
- No code changes to add/remove providers
- Status-based filtering (ACTIVE/INACTIVE)
- Client-specific preferences support

### Correlation IDs
Track requests across services:
```typescript
const correlationId = event.requestContext?.requestId || 
                     event.headers?.['X-Correlation-ID'] ||
                     crypto.randomUUID();
```

## References

- #[[file:docs/architecture/SYSTEM_ARCHITECTURE_DIAGRAM.md]]
- #[[file:docs/architecture/PROJECT_STRUCTURE.md]]
- #[[file:docs/architecture/ADAPTER_ARCHITECTURE.md]]
- #[[file:docs/architecture/DYNAMODB_SINGLE_TABLE_DESIGN.md]]
