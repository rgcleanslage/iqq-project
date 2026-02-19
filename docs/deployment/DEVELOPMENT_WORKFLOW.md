# Development Workflow Guide

Guide for developers working on unversioned code before it's deployed to a versioned API stage.

## Overview

The iQQ API uses versioned stages (v1-v9) for production and testing, but developers need a way to test changes before they're assigned to a version. This guide covers the development workflow.

## Development Approaches

### Option 1: Local Development with SAM (Recommended)

Test Lambda functions locally before deploying to AWS.

#### Setup

```bash
# Navigate to service directory
cd iqq-package-service

# Install dependencies
npm install

# Build the service
sam build
```

#### Run Locally

```bash
# Start local API
sam local start-api --port 3000

# Test endpoint
curl http://localhost:3000/package?productCode=MBP
```

#### Run with Environment Variables

```bash
# Create local env file
cat > env.json << EOF
{
  "Parameters": {
    "VERSION_STATUS": "dev",
    "VERSION_CURRENT": "dev",
    "VERSION_SUNSET_DATE": "null",
    "VERSION_MIGRATION_GUIDE": "https://docs.iqq.com/api/migration"
  }
}
EOF

# Start with env vars
sam local start-api --env-vars env.json --port 3000
```

#### Invoke Function Directly

```bash
# Create test event
cat > event.json << EOF
{
  "queryStringParameters": {
    "productCode": "MBP"
  },
  "headers": {
    "Authorization": "Bearer test-token"
  }
}
EOF

# Invoke function
sam local invoke PackageFunction --event event.json
```

### Option 2: Deploy to "dev" Stage

Create a dedicated "dev" stage for active development that's separate from versioned stages.

#### Create Dev Stage

```bash
# Get API Gateway ID
API_ID=$(aws apigateway get-rest-apis \
  --query 'items[?name==`iqq-api-dev`].id' --output text)

# Get latest deployment
DEPLOYMENT_ID=$(aws apigateway get-deployments \
  --rest-api-id $API_ID \
  --query 'items[0].id' --output text)

# Create dev stage
aws apigateway create-stage \
  --rest-api-id $API_ID \
  --stage-name dev \
  --deployment-id $DEPLOYMENT_ID \
  --description "Development stage for unversioned testing" \
  --variables lambdaAlias=latest
```

#### Deploy Services to "latest" Alias

```bash
# Deploy service (creates $LATEST version)
cd iqq-package-service
sam build
sam deploy

# Create or update "latest" alias
aws lambda create-alias \
  --function-name iqq-package-service-dev \
  --name latest \
  --function-version '$LATEST' \
  --description "Latest development version" \
  || \
aws lambda update-alias \
  --function-name iqq-package-service-dev \
  --name latest \
  --function-version '$LATEST'
```

#### Add Lambda Permissions for Dev Stage

```bash
API_ID=$(aws apigateway get-rest-apis \
  --query 'items[?name==`iqq-api-dev`].id' --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

for SERVICE in package lender product document; do
  FUNCTION_NAME="iqq-${SERVICE}-service-dev"
  
  # Remove old permission if exists
  aws lambda remove-permission \
    --function-name "${FUNCTION_NAME}:latest" \
    --statement-id "apigateway-dev-invoke" 2>/dev/null || true
  
  # Add permission
  aws lambda add-permission \
    --function-name "${FUNCTION_NAME}:latest" \
    --statement-id "apigateway-dev-invoke" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:us-east-1:${ACCOUNT_ID}:${API_ID}/dev/*/*"
done
```

#### Test Dev Stage

```bash
# Get OAuth token
TOKEN=$(curl -s -X POST \
  "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Test dev stage
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### Option 3: Feature Branches with Temporary Stages

Create temporary stages for feature branches.

#### Create Feature Stage

```bash
FEATURE_NAME="feature-new-pricing"

# Deploy services from feature branch
cd iqq-package-service
git checkout feature/new-pricing
sam build
sam deploy

# Create feature alias
aws lambda create-alias \
  --function-name iqq-package-service-dev \
  --name $FEATURE_NAME \
  --function-version $(aws lambda publish-version \
    --function-name iqq-package-service-dev \
    --query Version --output text)

# Create API Gateway stage
API_ID=$(aws apigateway get-rest-apis \
  --query 'items[?name==`iqq-api-dev`].id' --output text)
DEPLOYMENT_ID=$(aws apigateway get-deployments \
  --rest-api-id $API_ID \
  --query 'items[0].id' --output text)

aws apigateway create-stage \
  --rest-api-id $API_ID \
  --stage-name $FEATURE_NAME \
  --deployment-id $DEPLOYMENT_ID \
  --variables lambdaAlias=$FEATURE_NAME
```

#### Clean Up Feature Stage

```bash
# Delete stage
aws apigateway delete-stage \
  --rest-api-id $API_ID \
  --stage-name $FEATURE_NAME

# Delete aliases
for SERVICE in package lender product document; do
  aws lambda delete-alias \
    --function-name iqq-${SERVICE}-service-dev \
    --name $FEATURE_NAME
done
```

## Recommended Development Workflow

### 1. Local Development

```bash
# Make changes to code
cd iqq-package-service
vim src/index.ts

# Test locally
npm test
sam build
sam local start-api --port 3000

# Test endpoint
curl http://localhost:3000/package?productCode=MBP
```

### 2. Deploy to Dev Stage

```bash
# Deploy to AWS dev stage
sam build
sam deploy

# Update latest alias
aws lambda update-alias \
  --function-name iqq-package-service-dev \
  --name latest \
  --function-version '$LATEST'

# Test on AWS
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### 3. Create Version When Ready

```bash
# Create new version (e.g., v10)
gh workflow run add-new-version.yml -f new_version=v10 -f status=alpha

# Deploy to version
gh workflow run deploy-version.yml -f version=v10 -f environment=dev -f deploy_all=true
```

### 4. Promote Through Lifecycle

```bash
# Test in alpha
# ... testing ...

# Promote to beta
gh workflow run update-version-status.yml -f version=v10 -f new_status=beta

# More testing
# ... testing ...

# Promote to stable
gh workflow run update-version-status.yml -f version=v10 -f new_status=stable -f mark_as_current=true
```

## Environment Variables for Development

Set these environment variables in Lambda for development:

```bash
aws lambda update-function-configuration \
  --function-name iqq-package-service-dev \
  --environment "Variables={
    VERSION_STATUS=dev,
    VERSION_CURRENT=dev,
    VERSION_SUNSET_DATE=null,
    VERSION_MIGRATION_GUIDE=https://docs.iqq.com/api/migration,
    LOG_LEVEL=DEBUG
  }"
```

## Postman Setup for Development

### Create Dev Environment

Create a new Postman environment for the dev stage:

```json
{
  "name": "iQQ Dev Stage (Unversioned)",
  "values": [
    {
      "key": "baseUrl",
      "value": "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com",
      "enabled": true
    },
    {
      "key": "stage",
      "value": "dev",
      "enabled": true
    },
    {
      "key": "clientId",
      "value": "YOUR_CLIENT_ID",
      "enabled": true
    },
    {
      "key": "clientSecret",
      "value": "YOUR_CLIENT_SECRET",
      "type": "secret",
      "enabled": true
    },
    {
      "key": "apiKey",
      "value": "YOUR_API_KEY",
      "enabled": true
    }
  ]
}
```

### Update Requests for Dev Stage

Change URLs from:
```
{{baseUrl}}/v1/package
```

To:
```
{{baseUrl}}/{{stage}}/package
```

Or directly:
```
{{baseUrl}}/dev/package
```

## CI/CD for Development

### GitHub Actions for Dev Deployments

Create `.github/workflows/deploy-dev.yml`:

```yaml
name: Deploy to Dev Stage

on:
  push:
    branches:
      - develop
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Deploy Package Service
        run: |
          cd iqq-package-service
          sam build
          sam deploy --no-confirm-changeset
          
          # Update latest alias
          VERSION=$(aws lambda publish-version \
            --function-name iqq-package-service-dev \
            --query Version --output text)
          
          aws lambda update-alias \
            --function-name iqq-package-service-dev \
            --name latest \
            --function-version $VERSION
      
      - name: Test Dev Stage
        run: |
          # Get token and test endpoints
          ./scripts/test-dev-stage.sh
```

## Testing Strategy

### Unit Tests (Always)
```bash
npm test
```

### Local Integration Tests
```bash
sam local start-api &
./scripts/test-local-endpoints.sh
```

### Dev Stage Tests
```bash
./scripts/test-dev-stage.sh
```

### Version Tests (Before Promoting)
```bash
./scripts/test-version.sh v10
```

## Best Practices

### 1. Use Local Development First
- Faster iteration
- No AWS costs
- Easier debugging

### 2. Deploy to Dev Stage for Integration Testing
- Test with real AWS services
- Test OAuth flow
- Test with real DynamoDB data

### 3. Create Versions for Stakeholder Testing
- Use alpha status for internal testing
- Use beta status for stakeholder testing
- Promote to stable only after approval

### 4. Keep Dev Stage Clean
- Deploy frequently
- Don't use for long-term testing
- Use versions for anything that needs to persist

### 5. Use Feature Branches Sparingly
- Only for major features
- Clean up after merging
- Prefer dev stage for most work

## Troubleshooting

### Dev Stage Returns 500
**Problem:** Lambda alias doesn't exist or has wrong permissions

**Solution:**
```bash
# Check alias exists
aws lambda get-alias \
  --function-name iqq-package-service-dev \
  --name latest

# Recreate permissions
# (see "Add Lambda Permissions for Dev Stage" above)
```

### Local SAM Not Working
**Problem:** Can't connect to local API

**Solution:**
```bash
# Check Docker is running
docker ps

# Rebuild
sam build --use-container

# Try different port
sam local start-api --port 3001
```

### Changes Not Reflected
**Problem:** Deployed but seeing old code

**Solution:**
```bash
# Publish new version
VERSION=$(aws lambda publish-version \
  --function-name iqq-package-service-dev \
  --query Version --output text)

# Update alias to new version
aws lambda update-alias \
  --function-name iqq-package-service-dev \
  --name latest \
  --function-version $VERSION

# Force API Gateway to use new version
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev
```

## Related Documentation

- [API Versioning Guide](./API_VERSIONING_WITH_GITHUB_RELEASES.md) - Version management
- [Deployment Guide](./DEPLOYMENT_GUIDE.md) - Production deployments
- [CI/CD Setup](./CICD_SETUP_GUIDE.md) - Automated deployments
- [Testing Guide](../testing/README.md) - Testing strategies

---

**Last Updated:** February 19, 2026  
**Status:** Recommended Practices ✅
