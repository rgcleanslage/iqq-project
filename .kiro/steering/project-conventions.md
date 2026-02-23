---
inclusion: auto
description: Project conventions including naming standards, code style guidelines, Git workflow, environment variables, and security best practices
---

# Project Conventions

Standard conventions and best practices for the iQQ Insurance Quoting Platform.

## Project Information

- **AWS Account**: 785826687678
- **Region**: us-east-1
- **Environment**: dev (currently only environment)
- **GitHub Organization**: https://github.com/rgcleanslage/
- **Repository Visibility**: Public

## Naming Conventions

### AWS Resources

**Lambda Functions**:
- Pattern: `iqq-{service}-{environment}`
- Examples: `iqq-lender-dev`, `iqq-adapter-csv-dev`

**CloudFormation Stacks**:
- Pattern: `iqq-{service}-service` or `iqq-{component}`
- Examples: `iqq-lender-service`, `iqq-providers`

**DynamoDB Tables**:
- Pattern: `iqq-{purpose}-{environment}`
- Examples: `iqq-config-dev`, `iqq-documents-dev`

**API Gateway**:
- Pattern: `iqq-api-{environment}`
- Example: `iqq-api-dev`

**Step Functions**:
- Pattern: `iqq-{purpose}-orchestrator-{environment}`
- Example: `iqq-quote-orchestrator-dev`

**CloudWatch Log Groups**:
- Pattern: `/aws/lambda/iqq-{service}-{environment}`
- Example: `/aws/lambda/iqq-lender-dev`

### Code Structure

**TypeScript Files**:
- Use kebab-case: `response-builder.ts`, `pricing-service.ts`
- Index files: `index.ts` (entry point)
- Test files: `{name}.test.ts`

**Functions**:
- Use camelCase: `processRequest()`, `validateInput()`
- Lambda handlers: `export const handler = async (event) => {}`

**Interfaces/Types**:
- Use PascalCase: `Provider`, `ClientPreferences`
- Prefix interfaces with `I` only if needed for clarity

**Constants**:
- Use UPPER_SNAKE_CASE: `TABLE_NAME`, `MAX_RETRIES`

## Directory Structure

### Service Structure
```
service-name/
├── src/
│   ├── index.ts           ← Lambda handler
│   ├── config/            ← Configuration
│   ├── models/            ← Data models
│   ├── services/          ← Business logic
│   └── utils/             ← Utilities
├── tests/
│   └── index.test.ts      ← Unit tests
├── events/
│   └── test-event.json    ← Test events
├── dist/                  ← Compiled output (gitignored)
├── .aws-sam/              ← SAM build output (gitignored)
├── Makefile               ← Build instructions
├── template.yaml          ← SAM template
├── samconfig.toml         ← SAM config
├── package.json
├── tsconfig.json
└── README.md
```

### Infrastructure Structure
```
iqq-infrastructure/
├── modules/
│   ├── api-gateway/
│   ├── cognito/
│   ├── dynamodb/
│   ├── lambda-versioning/
│   └── step-functions/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── README.md
```

## Code Style

### TypeScript

**Use async/await** (not callbacks):
```typescript
// Good
const result = await dynamodb.send(command);

// Avoid
dynamodb.send(command, (err, data) => { ... });
```

**Use const/let** (not var):
```typescript
// Good
const TABLE_NAME = process.env.TABLE_NAME;
let counter = 0;

// Avoid
var TABLE_NAME = process.env.TABLE_NAME;
```

**Use template literals**:
```typescript
// Good
console.log(`Processing request ${requestId}`);

// Avoid
console.log('Processing request ' + requestId);
```

**Use destructuring**:
```typescript
// Good
const { productCode, coverageType } = event.queryStringParameters;

// Avoid
const productCode = event.queryStringParameters.productCode;
const coverageType = event.queryStringParameters.coverageType;
```

### Error Handling

**Always use try-catch**:
```typescript
export const handler = async (event: any) => {
  try {
    const result = await processRequest(event);
    return successResponse(result);
  } catch (error) {
    console.error('Error processing request', { error });
    return errorResponse(error);
  }
};
```

**Log errors with context**:
```typescript
console.error(JSON.stringify({
  level: 'ERROR',
  message: 'Failed to process request',
  correlationId,
  error: error.message,
  stack: error.stack,
  context: { productCode, coverageType }
}));
```

### Logging

**Use structured JSON logging**:
```typescript
console.log(JSON.stringify({
  level: 'INFO',
  message: 'Processing request',
  correlationId,
  productCode,
  coverageType,
  timestamp: new Date().toISOString()
}));
```

**Log levels**:
- `INFO`: Normal operations
- `WARN`: Unexpected but handled situations
- `ERROR`: Errors that need attention
- `DEBUG`: Detailed debugging information

**Always include correlation ID**:
```typescript
const correlationId = event.requestContext?.requestId || 
                     event.headers?.['X-Correlation-ID'] ||
                     crypto.randomUUID();
```

## Git Conventions

### Branch Strategy

**Main branch**: `main`
- Protected branch
- Requires pull request
- Auto-deploys to dev on merge

**Feature branches**:
- Pattern: `feature/{description}`
- Example: `feature/add-pricing-service`

**Bug fix branches**:
- Pattern: `fix/{description}`
- Example: `fix/step-functions-error`

**Release branches** (future):
- Pattern: `release/{version}`
- Example: `release/v1.0.0`

### Commit Messages

**Format**: `type: description`

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Build/config changes

**Examples**:
```
feat: add pricing service to package endpoint
fix: resolve Step Functions JSONPath error
docs: update README with local testing instructions
refactor: extract adapter logic to separate service
test: add unit tests for lender service
chore: update dependencies to latest versions
```

## Environment Variables

### Required Variables

**All Lambda Functions**:
```yaml
Environment:
  Variables:
    ENVIRONMENT: dev
    LOG_LEVEL: INFO
    AWS_REGION: us-east-1
```

**Functions using DynamoDB**:
```yaml
Environment:
  Variables:
    TABLE_NAME: iqq-config-dev
```

**Functions using Step Functions**:
```yaml
Environment:
  Variables:
    STATE_MACHINE_ARN: arn:aws:states:us-east-1:785826687678:stateMachine:iqq-quote-orchestrator-dev
```

**Authorizer**:
```yaml
Environment:
  Variables:
    COGNITO_USER_POOL_ID: us-east-1_Wau5rEb2N
    COGNITO_CLIENT_ID: 25oa5u3vup2jmhl270e7shudkl
```

### Secrets Management

**Never commit secrets** to version control.

**Use AWS Secrets Manager**:
```typescript
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const client = new SecretsManagerClient({ region: 'us-east-1' });
const command = new GetSecretValueCommand({ SecretId: 'cognito-client-secret' });
const response = await client.send(command);
const secret = JSON.parse(response.SecretString);
```

**Use environment variables for non-secrets**:
```typescript
const TABLE_NAME = process.env.TABLE_NAME || 'iqq-config-dev';
```

## API Conventions

### Request Headers

**Required**:
- `Authorization: Bearer {access_token}`
- `x-api-key: {api_key}`

**Optional**:
- `Content-Type: application/json`
- `X-Correlation-ID: {uuid}`

### Response Format

**Success (200)**:
```json
{
  "success": true,
  "data": { ... },
  "metadata": {
    "timestamp": "2026-02-23T10:00:00Z",
    "correlationId": "abc-123-def"
  }
}
```

**Error (4xx/5xx)**:
```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE",
  "metadata": {
    "timestamp": "2026-02-23T10:00:00Z",
    "correlationId": "abc-123-def"
  }
}
```

### Query Parameters

**Use camelCase**:
- `productCode` (not `product_code`)
- `coverageType` (not `coverage_type`)
- `vehicleValue` (not `vehicle_value`)

## DynamoDB Conventions

### Key Patterns

**Partition Key (PK)**:
- Format: `{ENTITY}#{ID}`
- Examples: `CLIENT#001`, `PROVIDER#PROV-CLIENT`

**Sort Key (SK)**:
- Format: `{TYPE}` or `{TYPE}#{ID}`
- Examples: `METADATA`, `PREFERENCES`, `FIELD#premium`

### GSI Patterns

**GSI1** (Entity Type Index):
- GSI1PK: `{ENTITY_TYPE}`
- GSI1SK: `{ENTITY}#{ID}`
- Use: Query all entities of a type

**GSI2** (Status Index):
- GSI2PK: `STATUS#{STATUS}`
- GSI2SK: `{ENTITY}#{ID}`
- Use: Query entities by status

### Attribute Naming

**Use camelCase**:
- `providerId`, `providerName`, `providerUrl`
- `clientId`, `clientName`, `allowedProviders`

## Documentation

### README Structure

Every service should have:
1. Overview
2. Features
3. API documentation
4. Development setup
5. Local testing
6. Deployment
7. Monitoring
8. Troubleshooting
9. Related repositories

### Code Comments

**Use JSDoc for functions**:
```typescript
/**
 * Load active providers from DynamoDB
 * @param clientId - Optional client ID for filtering
 * @returns Array of active providers
 */
async function loadProviders(clientId?: string): Promise<Provider[]> {
  // Implementation
}
```

**Comment complex logic**:
```typescript
// Sort providers by preference order
// Preferred providers come first, then others by rating
providers.sort((a, b) => {
  const aIndex = preferences.indexOf(a.providerId);
  const bIndex = preferences.indexOf(b.providerId);
  // ... sorting logic
});
```

## Testing Conventions

### Test File Naming

- Pattern: `{name}.test.ts`
- Location: `tests/` directory
- Example: `tests/index.test.ts`

### Test Structure

```typescript
describe('Service Name', () => {
  describe('handler', () => {
    it('should return success response', async () => {
      // Arrange
      const event = { ... };
      
      // Act
      const response = await handler(event);
      
      // Assert
      expect(response.statusCode).toBe(200);
    });
  });
});
```

### Test Coverage

- Minimum: 80% coverage
- Focus on business logic
- Test error scenarios
- Test edge cases

## Performance Guidelines

### Lambda Optimization

- Use ARM64 architecture
- Right-size memory (512MB default)
- Minimize cold starts (keep functions warm)
- Reuse SDK clients outside handler
- Use connection pooling for databases

### DynamoDB Optimization

- Use batch operations when possible
- Leverage GSIs for query patterns
- Use projection expressions to limit data
- Enable point-in-time recovery
- Monitor read/write capacity

### API Gateway Optimization

- Enable caching (if appropriate)
- Use compression
- Implement rate limiting
- Monitor throttling metrics

## Security Guidelines

### Authentication

- Always require OAuth token AND API key
- Validate tokens in custom authorizer
- Use short-lived tokens (1 hour)
- Rotate API keys periodically

### Authorization

- Implement least privilege IAM policies
- Use resource-based policies
- Validate user permissions in Lambda
- Log authorization decisions

### Data Protection

- Encrypt data at rest (DynamoDB)
- Encrypt data in transit (HTTPS)
- Never log sensitive data (tokens, keys)
- Use AWS Secrets Manager for secrets

## Cost Optimization

### Lambda

- Use ARM64 (20% cheaper)
- Right-size memory allocation
- Minimize execution time
- Use reserved concurrency sparingly

### DynamoDB

- Use on-demand pricing (for now)
- Monitor read/write patterns
- Consider provisioned capacity for predictable workloads
- Use TTL for temporary data

### CloudWatch

- 7-day log retention (not 30)
- Use log filtering to reduce volume
- Archive old logs to S3
- Delete unused log groups

## References

- #[[file:docs/architecture/PROJECT_STRUCTURE.md]]
- #[[file:docs/architecture/SYSTEM_ARCHITECTURE_DIAGRAM.md]]
- #[[file:DOCUMENTATION_INDEX.md]]
