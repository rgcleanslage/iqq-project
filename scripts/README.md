# iQQ Scripts

This directory contains utility scripts for the iQQ project.

## Test Runner Scripts

### Bash Version: `run-all-tests.sh`

Executes all test suites across all microservices and aggregates results.

**Usage:**
```bash
# Run all tests
./scripts/run-all-tests.sh

# Run with coverage reports
./scripts/run-all-tests.sh --coverage

# Run with verbose output
./scripts/run-all-tests.sh --verbose

# Combine options
./scripts/run-all-tests.sh --coverage --verbose
```

**Features:**
- Colored terminal output
- Automatic dependency installation
- Test result aggregation
- Coverage report generation
- Exit codes (0 = success, 1 = failures)

### Node.js Version: `run-all-tests.js`

Cross-platform test runner with additional features.

**Usage:**
```bash
# Run all tests
node scripts/run-all-tests.js

# Run with coverage reports
node scripts/run-all-tests.js --coverage

# Run with verbose output
node scripts/run-all-tests.js --verbose

# Output results as JSON
node scripts/run-all-tests.js --json

# Save JSON results to file
node scripts/run-all-tests.js --coverage --json > test-results.json
```

**Features:**
- Cross-platform (Windows, macOS, Linux)
- JSON output for CI/CD integration
- Coverage statistics extraction
- Detailed error reporting
- Duration tracking per service

## Other Scripts

### `seed-dynamodb.ts`

Seeds the DynamoDB configuration table with provider, product, and mapping data.

**Usage:**
```bash
cd scripts
npm install
npx ts-node seed-dynamodb.ts

# Or with custom table name
TABLE_NAME=iqq-config-prod npx ts-node seed-dynamodb.ts
```

**Note**: After deploying Lambda functions, you need to update the `providerUrl` fields with actual Function URLs. See `update-provider-urls.ts` below.

### `update-provider-urls.ts`

Updates provider records in DynamoDB with Lambda Function URLs from CloudFormation outputs.

**Usage:**
```bash
cd scripts
npm install

# Update URLs from CloudFormation stack
TABLE_NAME=iqq-config-dev STACK_NAME=iqq-providers-dev npx ts-node update-provider-urls.ts

# For production
TABLE_NAME=iqq-config-prod STACK_NAME=iqq-providers-prod npx ts-node update-provider-urls.ts
```

**When to use:**
- After deploying provider Lambdas with SAM/CloudFormation
- When Function URLs change
- During initial setup

**What it does:**
1. Fetches Lambda Function URLs from CloudFormation stack outputs
2. Updates DynamoDB provider records with actual URLs
3. Maintains `lambdaArn` for backward compatibility

### `export-diagrams.sh`

Exports Mermaid diagrams to PNG/SVG images.

**Usage:**
```bash
./scripts/export-diagrams.sh
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
      
      - name: Run Tests
        run: node scripts/run-all-tests.js --coverage --json > test-results.json
      
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results.json
      
      - name: Upload Coverage
        uses: actions/upload-artifact@v3
        with:
          name: coverage-reports
          path: |
            iqq-providers/coverage
            iqq-package-service/coverage
            iqq-lender-service/coverage
            iqq-product-service/coverage
            iqq-document-service/coverage
```

### GitLab CI Example

```yaml
test:
  stage: test
  image: node:20
  script:
    - node scripts/run-all-tests.js --coverage --json > test-results.json
  artifacts:
    reports:
      junit: test-results.json
    paths:
      - "*/coverage"
    expire_in: 30 days
```

### Jenkins Example

```groovy
pipeline {
  agent any
  
  stages {
    stage('Test') {
      steps {
        sh 'node scripts/run-all-tests.js --coverage --json > test-results.json'
      }
    }
    
    stage('Publish Results') {
      steps {
        publishHTML([
          reportDir: 'iqq-providers/coverage',
          reportFiles: 'index.html',
          reportName: 'Provider Coverage'
        ])
      }
    }
  }
}
```

## Test Result JSON Schema

When using `--json` flag, the output follows this schema:

```json
{
  "startTime": "2024-01-01T00:00:00.000Z",
  "endTime": "2024-01-01T00:05:00.000Z",
  "duration": 300,
  "services": [
    {
      "name": "Provider Services",
      "path": "iqq-providers",
      "status": "PASSED",
      "duration": 45,
      "details": "All tests passed",
      "coverage": {
        "lines": 85.5,
        "statements": 84.2,
        "functions": 88.1,
        "branches": 75.3
      }
    }
  ],
  "summary": {
    "total": 5,
    "passed": 4,
    "failed": 1,
    "skipped": 0
  }
}
```

## Troubleshooting

### Tests Not Found

If tests are not being discovered:
1. Ensure `package.json` has a `test` script
2. Check that test files match the pattern in `jest.config.js`
3. Verify `node_modules` are installed

### Coverage Not Generated

If coverage reports are missing:
1. Ensure `package.json` has a `test:coverage` script
2. Check `jest.config.js` has `collectCoverage` configuration
3. Verify write permissions in the service directory

### Permission Denied

If you get permission errors:
```bash
chmod +x scripts/run-all-tests.sh
chmod +x scripts/run-all-tests.js
```

## Contributing

When adding new services:
1. Add the service to the `services` array in both scripts
2. Ensure the service has `test` and `test:coverage` npm scripts
3. Follow the existing test structure and naming conventions
