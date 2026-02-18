# iQQ API Documentation

Complete API documentation for the iQQ Insurance Quote system.

## Quick Links

- [OpenAPI Specification](./openapi-complete.yaml) - Complete API spec with OAuth endpoint
- [Usage Guide](./OPENAPI_USAGE_GUIDE.md) - Detailed usage instructions
- [Postman Collection](./postman-collection.json) - Import into Postman
- [Postman Environment](./postman-environment.json) - Environment variables for Postman
- [Postman Troubleshooting](./POSTMAN_TROUBLESHOOTING.md) - Fix common Postman issues
- [Credential Encoder](./credential-encoder.html) - Web tool to encode credentials
- [Test Script](../../scripts/test-api-complete.sh) - Automated testing script

## Getting Started

### 1. Quick Test with cURL

```bash
# Set your client secret
export IQQ_CLIENT_SECRET="your-client-secret"

# Run the test script
./scripts/test-api-complete.sh
```

### 2. Using Postman

1. Import `postman-collection.json` into Postman
2. Import `postman-environment.json` as environment
3. Update `clientSecret` in environment variables
4. Use "Get OAuth Token (Alternative)" request (auto-encodes credentials)
5. Test other endpoints (token auto-refreshes)

**Having issues?** See [Postman Troubleshooting Guide](./POSTMAN_TROUBLESHOOTING.md)

**Need to encode credentials?** Open `credential-encoder.html` in your browser

### 3. Using Swagger UI

```bash
# Online
# Go to https://editor.swagger.io/
# Import openapi-complete.yaml

# Local with Docker
docker run -p 8080:8080 -e SWAGGER_JSON=/api/openapi-complete.yaml \
  -v $(pwd)/docs/api:/api swaggerapi/swagger-ui

# Open http://localhost:8080
```

## API Overview

### Base URLs

- **Dev**: `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev`
- **Prod**: `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/prod`

### Authentication

All endpoints require:
1. **OAuth 2.0 Bearer Token** - Get from Cognito OAuth endpoint
2. **API Key** - Include in `x-api-key` header

#### Get OAuth Token

```bash
curl -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "CLIENT_ID:CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=iqq-api/read"
```

Response:
```json
{
  "access_token": "eyJraWQiOiJxxx...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

## Endpoints

### Package Service
**GET /package** - Multi-provider quote orchestration

Query Parameters:
- `productCode` (optional): Product code (default: MBP)
- `coverageType` (optional): Coverage type (default: COMPREHENSIVE)
- `vehicleValue` (optional): Vehicle value in USD (default: 25000)
- `term` (optional): Coverage term (default: "60 months")

Example:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60%20months" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### Lender Service
**GET /lender** - Get lender information

Example:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### Product Service
**GET /product** - Get product information

Example:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/product" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### Document Service
**GET /document** - Get document information

Example:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/document" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

## Response Examples

### Package Response
```json
{
  "packageId": "PKG-1771346662785",
  "packageName": "Multi-Provider Quote Package",
  "providerQuotes": [
    {
      "provider": "Route 66 Insurance",
      "premium": 1149.99,
      "providerRating": "A"
    },
    {
      "provider": "Client Insurance",
      "premium": 1249.99,
      "providerRating": "A+"
    },
    {
      "provider": "APCO Insurance",
      "premium": 1287.49,
      "providerRating": "A-"
    }
  ],
  "pricing": {
    "basePrice": 1149.99,
    "discountPercentage": 5,
    "totalPrice": 1092.49,
    "averagePremium": 1229.16
  },
  "bestQuote": {
    "provider": "Route 66 Insurance",
    "premium": 1149.99,
    "savings": 79.17
  },
  "summary": {
    "totalQuotes": 3,
    "successfulQuotes": 3,
    "failedProviders": 0
  }
}
```

## Client SDK Generation

Generate client SDKs in various languages:

### TypeScript
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/api/openapi-complete.yaml \
  -g typescript-axios \
  -o ./generated/typescript-client
```

### Python
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/api/openapi-complete.yaml \
  -g python \
  -o ./generated/python-client
```

### Java
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/api/openapi-complete.yaml \
  -g java \
  -o ./generated/java-client
```

### Go
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/api/openapi-complete.yaml \
  -g go \
  -o ./generated/go-client
```

## Error Handling

### HTTP Status Codes

- `200` - Success
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (missing/invalid API key)
- `500` - Internal Server Error

### Error Response Format

```json
{
  "message": "Unauthorized",
  "error": "invalid_token",
  "correlationId": "a4d5672e-6d2c-4af3-9d88-b0a0b04b370b"
}
```

## Rate Limiting

API Gateway enforces rate limits based on usage plans:

- **Standard Plan**: 1000 requests/day, 10 requests/second
- **Premium Plan**: 10000 requests/day, 100 requests/second

## Security Best Practices

1. **Never commit credentials** - Use environment variables
2. **Rotate secrets regularly** - Update client secrets and API keys
3. **Use HTTPS only** - All requests must use HTTPS
4. **Token expiration** - Tokens expire after 1 hour, implement refresh logic
5. **Store tokens securely** - Never log or expose tokens

## Troubleshooting

### 401 Unauthorized
- Token expired (tokens last 1 hour)
- Token not included in Authorization header
- Invalid token format (must be `Bearer <token>`)

### 403 Forbidden
- API key missing from x-api-key header
- Invalid or revoked API key
- API key not associated with usage plan

### 500 Internal Server Error
- Check CloudWatch logs: `/aws/lambda/iqq-*-service-dev`
- Contact support with correlation ID from response

## Support

- **Email**: api-support@iqq.com
- **Documentation**: See [OPENAPI_USAGE_GUIDE.md](./OPENAPI_USAGE_GUIDE.md)
- **CloudWatch Logs**: `/aws/lambda/iqq-*-service-dev`

## Related Documentation

- [Deployment Guide](../deployment/DEPLOYMENT_GUIDE.md)
- [Architecture Overview](../architecture/PROJECT_STRUCTURE.md)
- [Step Functions Integration](../deployment/STEP_FUNCTIONS_FIX_COMPLETE.md)
