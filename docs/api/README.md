# iQQ API Documentation

Complete API documentation for the iQQ Insurance Quote system with versioning support.

## Quick Links

- [OpenAPI Specification](./openapi-complete.yaml) - Complete API spec with OAuth endpoint
- [Usage Guide](./OPENAPI_USAGE_GUIDE.md) - Detailed usage instructions
- [Version Headers](./API_VERSION_HEADERS.md) - API versioning documentation
- [Postman Collection](./postman-collection-versioned.json) - Versioned collection (v1-v9)
- [Postman Setup Guide](./POSTMAN_VERSIONED_SETUP.md) - Complete setup guide for versioned collection
- [Postman Troubleshooting](./POSTMAN_TROUBLESHOOTING.md) - Fix common Postman issues
- [Credential Encoder](./credential-encoder.html) - Web tool to encode credentials
- [Secrets Management](./SECRETS_MANAGEMENT.md) - How secrets are managed

## API Versioning

The iQQ API uses GitHub Releases for version management. Each version is deployed as a separate API Gateway stage with Lambda aliases.

### Available Versions

- **v1** - Stable (current production version)
- **v2-v9** - Deployed and available for testing

### Version Lifecycle

Versions progress through these stages:
- **planned** - Version created but not yet deployed
- **alpha** - Early testing phase
- **beta** - Feature complete, testing in progress
- **stable** - Production ready
- **deprecated** - Still available but scheduled for removal
- **sunset** - No longer available

See [API_VERSIONING_SETUP.md](./API_VERSIONING_SETUP.md) for complete versioning documentation.

## Getting Started

### 1. Choose Your API Version

All endpoints support versioning via the URL path:

```bash
# Use v1 (stable)
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package

# Use v2 (testing)
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/package
```

### 2. Get OAuth Token

```bash
# Get token from Cognito
curl -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "YOUR_CLIENT_ID:YOUR_CLIENT_SECRET" \
  -d "grant_type=client_credentials"
```

### 3. Make API Request

```bash
# Call API with token and API key
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### 4. Using Postman

1. Import `postman-collection-versioned.json` into Postman
2. Import one of the environment templates:
   - `postman-environment-default.template.json`
   - `postman-environment-partner-a.template.json`
   - `postman-environment-partner-b.template.json`
3. Update `clientSecret` and `apiKey` in environment variables
4. Use "Get OAuth Token" request to authenticate
5. Test endpoints across different versions (v1-v9)

**Complete Setup Guide:** See [POSTMAN_VERSIONED_SETUP.md](./POSTMAN_VERSIONED_SETUP.md)

**Having issues?** See [Postman Troubleshooting Guide](./POSTMAN_TROUBLESHOOTING.md)

**Need to encode credentials?** Open `credential-encoder.html` in your browser

## API Overview

### Base URLs

All API versions are available at:
```
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/{version}/
```

Where `{version}` is: v1, v2, v3, v4, v5, v6, v7, v8, or v9

**Current Stable Version:** v1  
**Latest Version:** v9

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
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60%20months" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

Response includes version metadata:
```json
{
  "packageId": "PKG-1771346662785",
  "metadata": {
    "apiVersion": "v1",
    "versionStatus": "stable",
    "deprecationDate": null,
    "sunsetDate": null
  }
}
```

### Lender Service
**GET /{version}/lender** - Get lender information

Query Parameters:
- `lenderId` (optional): Lender identifier

Example:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/lender?lenderId=LENDER-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### Product Service
**GET /{version}/product** - Get product information

Query Parameters:
- `productId` (optional): Product identifier

Example:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/product?productId=PROD-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### Document Service
**GET /{version}/document** - Get document information

Example:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/document" \
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

- [API Versioning Guide](../../deployment/API_VERSIONING_WITH_GITHUB_RELEASES.md) - Complete versioning documentation
- [Version Headers](./API_VERSION_HEADERS.md) - Version header documentation
- [Deployment Guide](../deployment/DEPLOYMENT_GUIDE.md) - Deployment instructions
- [Architecture Overview](../architecture/PROJECT_STRUCTURE.md) - System architecture
- [Secrets Management](./SECRETS_MANAGEMENT.md) - How secrets are managed
- [Postman Setup](./POSTMAN_STEP_BY_STEP.md) - Postman configuration guide

---

**Last Updated:** February 19, 2026  
**API Version:** v1 (stable), v2-v9 (available)  
**Status:** Production Ready ✅
