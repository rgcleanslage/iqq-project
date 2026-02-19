# Testing Documentation

Complete testing documentation for the iQQ Insurance Quoting Platform.

## Quick Start

### API Testing with SoapUI
1. [SOAPUI_QUICK_START.md](./SOAPUI_QUICK_START.md) - Quick start guide
2. [SOAPUI_TESTING_GUIDE.md](./SOAPUI_TESTING_GUIDE.md) - Complete testing guide
3. [iQQ-API-SoapUI-Project.xml](./iQQ-API-SoapUI-Project.xml) - Import this project

### Command Line Testing
```bash
# Test all endpoints for a specific version
./docs/testing/test-all-endpoints.sh v1

# Test with custom credentials
API_KEY=your-key CLIENT_ID=your-id CLIENT_SECRET=your-secret \
  ./docs/testing/test-all-endpoints.sh v1
```

## Documentation Index

### Testing Guides
- **[SOAPUI_TESTING_GUIDE.md](./SOAPUI_TESTING_GUIDE.md)** - Complete SoapUI testing guide with setup and examples
- **[SOAPUI_QUICK_START.md](./SOAPUI_QUICK_START.md)** - Quick start for SoapUI testing

### Test Resources
- **[iQQ-API-SoapUI-Project.xml](./iQQ-API-SoapUI-Project.xml)** - SoapUI project file with all endpoints
- **[test-all-endpoints.sh](./test-all-endpoints.sh)** - Bash script to test all endpoints

## Testing Approach

### Unit Testing
Each service has comprehensive unit tests using Jest:

```bash
# Run tests for a service
cd iqq-package-service
npm test

# Run with coverage
npm test -- --coverage
```

**Current Coverage:** 73% across all services

### Integration Testing
API integration tests verify end-to-end functionality:

1. **OAuth Authentication** - Verify token generation
2. **API Gateway** - Test routing and authorization
3. **Lambda Functions** - Verify business logic
4. **Step Functions** - Test orchestration
5. **Provider Integration** - Verify external calls

### API Testing Tools

#### 1. SoapUI (Recommended)
- Complete project file included
- OAuth 2.0 authentication configured
- All endpoints pre-configured
- Environment variables for easy switching

#### 2. Postman
- Collections available in `docs/api/`
- OAuth 2.0 support
- Environment templates for different clients

#### 3. cURL
- Test scripts in `docs/testing/`
- Works on any platform
- Easy to automate

## Test Scenarios

### 1. Authentication Testing

**Test OAuth Token Generation:**
```bash
curl -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "CLIENT_ID:CLIENT_SECRET" \
  -d "grant_type=client_credentials"
```

**Expected:** 200 OK with access_token

### 2. API Endpoint Testing

**Test Package Service:**
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

**Expected:** 200 OK with quote package

### 3. Version Testing

**Test Multiple Versions:**
```bash
# Test v1
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package" \
  -H "Authorization: Bearer $TOKEN" -H "x-api-key: $API_KEY"

# Test v2
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/package" \
  -H "Authorization: Bearer $TOKEN" -H "x-api-key: $API_KEY"
```

**Expected:** Both return 200 OK with version metadata

### 4. Error Handling Testing

**Test Invalid Token:**
```bash
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package" \
  -H "Authorization: Bearer invalid-token" -H "x-api-key: $API_KEY"
```

**Expected:** 401 Unauthorized

**Test Missing API Key:**
```bash
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected:** 403 Forbidden

### 5. Deprecation Testing

**Test Deprecated Version:**
```bash
# Deprecate a version first
gh workflow run deprecate-version.yml -f version=v1 -f sunset_days=90

# Test the endpoint
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package" \
  -H "Authorization: Bearer $TOKEN" -H "x-api-key: $API_KEY" -v
```

**Expected:** 200 OK with deprecation headers:
- `X-API-Deprecation-Date`
- `X-API-Sunset-Date`
- `X-API-Migration-Guide`

## Automated Testing

### GitHub Actions Verification

The `deploy-version.yml` workflow includes automated verification:

1. **OAuth Token Generation** - Retrieves credentials from Secrets Manager
2. **Endpoint Testing** - Tests all 4 services
3. **Retry Logic** - 3 attempts with 10-second delays
4. **Error Reporting** - Detailed failure messages

### Continuous Testing

Set up continuous testing with GitHub Actions:

```yaml
name: API Tests
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test API
        run: ./docs/testing/test-all-endpoints.sh v1
```

## Test Data

### Sample Requests

**Package Service:**
```json
{
  "productCode": "MBP",
  "coverageType": "COMPREHENSIVE",
  "vehicleValue": 25000,
  "term": "60 months"
}
```

**Lender Service:**
```json
{
  "lenderId": "LENDER-001"
}
```

**Product Service:**
```json
{
  "productId": "PROD-001"
}
```

### Expected Responses

**Package Service Response:**
```json
{
  "packageId": "PKG-1771346662785",
  "packageName": "Multi-Provider Quote Package",
  "providerQuotes": [
    {
      "provider": "Route 66 Insurance",
      "premium": 1149.99,
      "providerRating": "A"
    }
  ],
  "pricing": {
    "basePrice": 1149.99,
    "discountPercentage": 5,
    "totalPrice": 1092.49
  },
  "metadata": {
    "apiVersion": "v1",
    "versionStatus": "stable"
  }
}
```

## Performance Testing

### Load Testing with Artillery

```yaml
# artillery-config.yml
config:
  target: "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com"
  phases:
    - duration: 60
      arrivalRate: 10
scenarios:
  - name: "Package Service"
    flow:
      - get:
          url: "/v1/package?productCode=MBP"
          headers:
            Authorization: "Bearer {{token}}"
            x-api-key: "{{apiKey}}"
```

Run with:
```bash
artillery run artillery-config.yml
```

### Expected Performance

- **Response Time:** < 2 seconds (p95)
- **Throughput:** 100 requests/second
- **Error Rate:** < 1%

## Monitoring Test Results

### CloudWatch Logs

```bash
# View Lambda logs
aws logs tail /aws/lambda/iqq-package-service-dev --follow

# Filter for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/iqq-package-service-dev \
  --filter-pattern "ERROR"
```

### API Gateway Metrics

```bash
# Get API Gateway metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=iqq-api-dev \
  --start-time 2026-02-19T00:00:00Z \
  --end-time 2026-02-19T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### X-Ray Tracing

View traces in AWS X-Ray console:
1. Go to AWS X-Ray console
2. Select "Service Map"
3. View traces for specific requests
4. Analyze performance bottlenecks

## Troubleshooting

### Common Issues

**401 Unauthorized:**
- Token expired (tokens last 1 hour)
- Invalid client credentials
- Token not in Authorization header

**403 Forbidden:**
- Missing or invalid API key
- API key not in usage plan
- Rate limit exceeded

**500 Internal Server Error:**
- Check CloudWatch logs
- Verify Lambda function is deployed
- Check Lambda alias exists

**Timeout:**
- Increase Lambda timeout
- Check provider response times
- Review Step Functions execution

### Debug Mode

Enable debug logging:

```bash
# Set environment variable
aws lambda update-function-configuration \
  --function-name iqq-package-service-dev \
  --environment "Variables={LOG_LEVEL=DEBUG}"

# Test and view logs
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package" \
  -H "Authorization: Bearer $TOKEN" -H "x-api-key: $API_KEY"

aws logs tail /aws/lambda/iqq-package-service-dev --follow
```

## Best Practices

### Testing Strategy
1. Test authentication before testing endpoints
2. Test each version separately
3. Verify error handling
4. Check deprecation headers
5. Monitor performance metrics

### Test Automation
1. Run tests after each deployment
2. Schedule regular API health checks
3. Alert on test failures
4. Track test coverage

### Security Testing
1. Never commit credentials to git
2. Use AWS Secrets Manager for credentials
3. Rotate test credentials regularly
4. Test with different client IDs

## Related Documentation

- [API Documentation](../api/README.md) - API reference
- [Deployment Guide](../deployment/DEPLOYMENT_GUIDE.md) - Deployment instructions
- [Postman Setup](../api/POSTMAN_STEP_BY_STEP.md) - Postman configuration
- [Secrets Management](../deployment/SECRETS_MANAGER_SETUP.md) - Secrets configuration

---

**Last Updated:** February 19, 2026  
**Test Coverage:** 73% (unit tests)  
**Status:** Production Ready ✅
