---
inclusion: auto
description: Testing practices including local Lambda testing with SAM, debugging with VS Code, unit/integration tests, and SoapUI testing
---

# Testing Practices

This project uses multiple testing approaches for different layers of the application.

## Local Lambda Testing

### SAM Local Invoke

**IMPORTANT**: This project's SAM templates don't include API Gateway events (API Gateway is managed by Terraform separately). Use `sam local invoke` to test Lambda functions directly, not `sam local start-api`.

#### Create Test Events

Create `events/test-event.json` in each service:

```json
{
  "httpMethod": "GET",
  "path": "/lender",
  "queryStringParameters": {
    "lenderId": "LENDER-001"
  },
  "headers": {
    "Authorization": "Bearer eyJraWQiOiJ...",
    "x-api-key": "your-api-key-here",
    "Content-Type": "application/json"
  },
  "requestContext": {
    "requestId": "test-request-id",
    "authorizer": {
      "claims": {
        "sub": "test-user-id",
        "client_id": "test-client-id"
      }
    }
  },
  "body": null
}
```

#### Invoke Lambda Locally

```bash
# Build first
npm run build
sam build

# Invoke with test event
sam local invoke FunctionName -e events/test-event.json

# With environment variables
sam local invoke FunctionName -e events/test-event.json --env-vars env.json

# With debug output
sam local invoke FunctionName -e events/test-event.json --debug
```

#### Environment Variables File

Create `env.json`:

```json
{
  "FunctionName": {
    "ENVIRONMENT": "dev",
    "LOG_LEVEL": "DEBUG",
    "TABLE_NAME": "iqq-config-dev"
  }
}
```

### Debugging with VS Code

#### Prerequisites

Ensure source maps are enabled in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "sourceMap": true,
    "inlineSourceMap": false
  }
}
```

#### Debug Steps

1. Set breakpoints in TypeScript source files (`src/index.ts`)

2. Build with source maps:
   ```bash
   npm run build
   sam build
   ```

3. Start SAM in debug mode (in terminal):
   ```bash
   sam local invoke -d 5858 FunctionName -e events/test-event.json
   ```

4. Attach VS Code debugger:
   - Press F5 or Run > Start Debugging
   - Select "Attach to SAM Local"
   - Debugger connects and execution begins

5. Debug: Step through code, inspect variables, evaluate expressions

#### VS Code Launch Configuration

`.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to SAM Local",
      "type": "node",
      "request": "attach",
      "port": 5858,
      "address": "localhost",
      "localRoot": "${workspaceFolder}/dist",
      "remoteRoot": "/var/task",
      "protocol": "inspector",
      "stopOnEntry": false,
      "sourceMaps": true
    }
  ]
}
```

## Unit Testing

### Jest Configuration

`jest.config.js`:

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
};
```

### Test Structure

`tests/index.test.ts`:

```typescript
import { handler } from '../src/index';

describe('Lender Service', () => {
  it('should return lender information', async () => {
    const event = {
      httpMethod: 'GET',
      path: '/lender',
      queryStringParameters: { lenderId: 'LENDER-001' },
      headers: {},
      requestContext: { requestId: 'test-123' }
    };
    
    const response = await handler(event);
    
    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toHaveProperty('lenderId');
  });
  
  it('should handle errors gracefully', async () => {
    const event = {
      httpMethod: 'GET',
      path: '/lender',
      queryStringParameters: null,
      headers: {},
      requestContext: { requestId: 'test-123' }
    };
    
    const response = await handler(event);
    
    expect(response.statusCode).toBe(500);
  });
});
```

### Run Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Watch mode
npm run test:watch

# Run specific test file
npm test -- tests/index.test.ts
```

## Integration Testing

### API Gateway Testing

Test deployed endpoints with real authentication:

```bash
# Get OAuth token
ACCESS_TOKEN=$(curl -X POST https://iqq-auth-dev.auth.us-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic $(echo -n 'CLIENT_ID:CLIENT_SECRET' | base64)" \
  -d "grant_type=client_credentials&scope=api/read api/write" \
  | jq -r '.access_token')

# Test endpoint
curl -X GET https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-api-key: Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH" \
  -v
```

### Step Functions Testing

Test state machine execution:

```bash
# Start execution
aws stepfunctions start-sync-execution \
  --state-machine-arn arn:aws:states:us-east-1:785826687678:stateMachine:iqq-quote-orchestrator-dev \
  --input '{
    "productCode": "MBP",
    "coverageType": "COMPREHENSIVE",
    "vehicleValue": 25000,
    "term": 60,
    "clientId": "CLIENT-001"
  }'

# View execution history
aws stepfunctions get-execution-history \
  --execution-arn <execution-arn> \
  --max-results 100
```

### DynamoDB Testing

Verify data in DynamoDB:

```bash
# Query active providers
aws dynamodb query \
  --table-name iqq-config-dev \
  --index-name GSI2 \
  --key-condition-expression "GSI2PK = :pk AND begins_with(GSI2SK, :provider)" \
  --expression-attribute-values '{
    ":pk": {"S": "STATUS#ACTIVE"},
    ":provider": {"S": "PROVIDER#"}
  }'

# Get specific item
aws dynamodb get-item \
  --table-name iqq-config-dev \
  --key '{
    "PK": {"S": "PROVIDER#PROV-CLIENT"},
    "SK": {"S": "METADATA"}
  }'
```

## SoapUI Testing

### Setup

1. Import project: `docs/testing/iQQ-API-SoapUI-Project.xml`
2. Configure environment variables:
   - `BASE_URL`: https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev
   - `API_KEY`: Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH
   - `ACCESS_TOKEN`: (get from Cognito)

### Run Tests

```bash
# Command line
cd docs/testing
./test-all-endpoints.sh

# Or use SoapUI GUI
# File > Import Project > iQQ-API-SoapUI-Project.xml
# Right-click TestSuite > Run
```

### Test Cases

- Authentication tests (401, 403 scenarios)
- Lender endpoint (GET with various parameters)
- Product endpoint (GET with product codes)
- Package endpoint (GET with quote parameters)
- Document endpoint (GET with document IDs)
- Error handling (invalid inputs, missing parameters)

## Load Testing

### Artillery Configuration

`artillery.yml`:

```yaml
config:
  target: "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com"
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 120
      arrivalRate: 50
      name: "Sustained load"
  defaults:
    headers:
      Authorization: "Bearer {{ $processEnvironment.ACCESS_TOKEN }}"
      x-api-key: "{{ $processEnvironment.API_KEY }}"

scenarios:
  - name: "Get package quote"
    flow:
      - get:
          url: "/dev/package"
          qs:
            productCode: "MBP"
            coverageType: "COMPREHENSIVE"
            vehicleValue: 25000
            term: 60
```

### Run Load Tests

```bash
# Install Artillery
npm install -g artillery

# Run test
export ACCESS_TOKEN="..."
export API_KEY="Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH"
artillery run artillery.yml
```

## Monitoring During Tests

### CloudWatch Logs

```bash
# Tail logs during testing
aws logs tail /aws/lambda/iqq-lender-dev --follow

# Filter for errors
aws logs tail /aws/lambda/iqq-lender-dev --follow --filter-pattern "ERROR"

# Filter for specific correlation ID
aws logs tail /aws/lambda/iqq-lender-dev --follow --filter-pattern "test-123"
```

### X-Ray Traces

```bash
# Get traces from last 5 minutes
aws xray get-trace-summaries \
  --start-time $(date -u -d '5 minutes ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression 'service("iqq-lender-service")'
```

### CloudWatch Metrics

```bash
# Get Lambda invocation count
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=iqq-lender-dev \
  --start-time $(date -u -d '10 minutes ago' --iso-8601=seconds) \
  --end-time $(date -u --iso-8601=seconds) \
  --period 60 \
  --statistics Sum
```

## Test Data Management

### Seed Test Data

```bash
cd scripts
npm install
npx ts-node seed-dynamodb.ts
```

### Clean Test Data

```bash
# Delete all items in table (careful!)
aws dynamodb scan --table-name iqq-config-dev \
  --attributes-to-get PK SK \
  --query 'Items[*].[PK.S, SK.S]' \
  --output text | \
  while read pk sk; do
    aws dynamodb delete-item \
      --table-name iqq-config-dev \
      --key "{\"PK\":{\"S\":\"$pk\"},\"SK\":{\"S\":\"$sk\"}}"
  done
```

## Common Testing Issues

### Issue: "Cannot find module"

**Cause**: TypeScript not compiled

**Solution**:
```bash
npm run build
sam build
```

### Issue: "Connection refused" in SAM Local

**Cause**: Docker not running

**Solution**:
```bash
# Start Docker
open -a Docker  # macOS
sudo systemctl start docker  # Linux
```

### Issue: "Timeout" in SAM Local

**Cause**: Function taking too long

**Solution**: Increase timeout in template.yaml
```yaml
Timeout: 60  # seconds
```

### Issue: "401 Unauthorized" in integration tests

**Cause**: Expired OAuth token

**Solution**: Get fresh token from Cognito
```bash
# Token expires after 1 hour
ACCESS_TOKEN=$(curl -X POST ... | jq -r '.access_token')
```

## Test Coverage Goals

- Unit tests: 80% coverage minimum
- Integration tests: All endpoints
- Load tests: 50 requests/second sustained
- Error scenarios: All 4xx and 5xx responses

## References

- #[[file:docs/testing/README.md]]
- #[[file:docs/testing/SOAPUI_TESTING_GUIDE.md]]
- #[[file:docs/testing/SOAPUI_QUICK_START.md]]
- #[[file:docs/deployment/TESTING_QUICK_START.md]]
