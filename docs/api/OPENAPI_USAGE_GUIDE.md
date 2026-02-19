# OpenAPI Usage Guide

## Overview
The `openapi-complete.yaml` file provides a complete specification for the iQQ Insurance Quote API, including authentication via AWS Cognito OAuth 2.0.

## Quick Start

### 1. View the API Documentation

You can view the OpenAPI specification using various tools:

#### Swagger UI (Online)
1. Go to https://editor.swagger.io/
2. File → Import File → Select `openapi-complete.yaml`
3. View interactive documentation

#### Swagger UI (Local)
```bash
# Using Docker
docker run -p 8080:8080 -e SWAGGER_JSON=/api/openapi-complete.yaml \
  -v $(pwd)/docs/api:/api swaggerapi/swagger-ui

# Open browser to http://localhost:8080
```

#### Postman
1. Open Postman
2. Import → Upload Files → Select `openapi-complete.yaml`
3. Collection will be created with all endpoints

### 2. Authentication Flow

#### Step 1: Get OAuth Token

```bash
# Set your credentials
CLIENT_ID="YOUR_CLIENT_ID"
CLIENT_SECRET="your-client-secret"
COGNITO_DOMAIN="iqq-dev-ib9i1hvt"

# Get access token
curl -X POST "https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
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

#### Step 2: Use Token in API Calls

```bash
TOKEN="your-access-token"
API_KEY="YOUR_API_KEY"

# Call any endpoint
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60%20months" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

## API Endpoints

### Authentication

#### POST /oauth/token
Get OAuth 2.0 access token from Cognito.

**Server**: `https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com`

**Authentication**: Basic Auth (Client ID:Client Secret)

**Request Body** (application/x-www-form-urlencoded):
```
grant_type=client_credentials
scope=iqq-api/read
```

**Response**:
```json
{
  "access_token": "eyJraWQiOiJxxx...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

### Package Service

#### GET /package
Get multi-provider quote package with aggregated pricing.

**Query Parameters**:
- `productCode` (optional): Product code (default: MBP)
- `coverageType` (optional): Coverage type (default: COMPREHENSIVE)
- `vehicleValue` (optional): Vehicle value in USD (default: 25000)
- `term` (optional): Coverage term (default: "60 months")

**Example**:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60%20months" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

**Response**: See schema `Package` in OpenAPI spec

### Lender Service

#### GET /lender
Get lender information including contact details and ratings.

**Example**:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

**Response**: See schema `Lender` in OpenAPI spec

### Product Service

#### GET /product
Get product information including coverage details and available providers.

**Example**:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/product" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

**Response**: See schema `Product` in OpenAPI spec

### Document Service

#### GET /document
Get document metadata and access information.

**Example**:
```bash
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/document" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

**Response**: See schema `Document` in OpenAPI spec

## Code Generation

### Generate Client SDK

You can generate client SDKs in various languages using the OpenAPI Generator:

#### JavaScript/TypeScript
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/api/openapi-complete.yaml \
  -g typescript-axios \
  -o ./generated/typescript-client
```

#### Python
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/api/openapi-complete.yaml \
  -g python \
  -o ./generated/python-client
```

#### Java
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/api/openapi-complete.yaml \
  -g java \
  -o ./generated/java-client
```

#### Go
```bash
npx @openapitools/openapi-generator-cli generate \
  -i docs/api/openapi-complete.yaml \
  -g go \
  -o ./generated/go-client
```

## Testing with Postman

### Import Collection
1. Open Postman
2. Click "Import" button
3. Select `openapi-complete.yaml`
4. Collection "iQQ Insurance Quote API" will be created

### Configure Environment
1. Create new environment "iQQ Dev"
2. Add variables:
   - `baseUrl`: `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev`
   - `cognitoUrl`: `https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com`
   - `clientId`: `YOUR_CLIENT_ID`
   - `clientSecret`: `your-client-secret`
   - `apiKey`: `YOUR_API_KEY`
   - `accessToken`: (will be set by pre-request script)

### Add Pre-Request Script
Add this to collection-level pre-request script to auto-refresh token:

```javascript
// Check if token exists and is not expired
const tokenExpiry = pm.environment.get('tokenExpiry');
const now = Date.now();

if (!tokenExpiry || now >= tokenExpiry) {
    // Get new token
    const clientId = pm.environment.get('clientId');
    const clientSecret = pm.environment.get('clientSecret');
    const cognitoUrl = pm.environment.get('cognitoUrl');
    
    const authString = btoa(`${clientId}:${clientSecret}`);
    
    pm.sendRequest({
        url: `${cognitoUrl}/oauth2/token`,
        method: 'POST',
        header: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${authString}`
        },
        body: {
            mode: 'urlencoded',
            urlencoded: [
                { key: 'grant_type', value: 'client_credentials' },
                { key: 'scope', value: 'iqq-api/read' }
            ]
        }
    }, (err, response) => {
        if (err) {
            console.error('Error getting token:', err);
        } else {
            const jsonData = response.json();
            pm.environment.set('accessToken', jsonData.access_token);
            // Set expiry to 5 minutes before actual expiry
            const expiryTime = now + ((jsonData.expires_in - 300) * 1000);
            pm.environment.set('tokenExpiry', expiryTime);
        }
    });
}
```

## Testing with cURL

### Complete Test Script

```bash
#!/bin/bash

# Configuration
CLIENT_ID="YOUR_CLIENT_ID"
CLIENT_SECRET="your-client-secret"
COGNITO_DOMAIN="iqq-dev-ib9i1hvt"
API_BASE_URL="https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev"
API_KEY="YOUR_API_KEY"

# Get OAuth token
echo "Getting OAuth token..."
TOKEN_RESPONSE=$(curl -s -X POST "https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read")

TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "Failed to get token"
    echo $TOKEN_RESPONSE
    exit 1
fi

echo "Token obtained successfully"
echo ""

# Test Lender endpoint
echo "=== Testing Lender Endpoint ==="
curl -s -X GET "${API_BASE_URL}/lender" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}" | jq .
echo ""

# Test Product endpoint
echo "=== Testing Product Endpoint ==="
curl -s -X GET "${API_BASE_URL}/product" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}" | jq .
echo ""

# Test Document endpoint
echo "=== Testing Document Endpoint ==="
curl -s -X GET "${API_BASE_URL}/document" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}" | jq .
echo ""

# Test Package endpoint
echo "=== Testing Package Endpoint ==="
curl -s -X GET "${API_BASE_URL}/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60%20months" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}" | jq .
echo ""
```

Save as `test-api.sh` and run:
```bash
chmod +x test-api.sh
./test-api.sh
```

## Security Considerations

1. **Never commit credentials**: Keep `CLIENT_SECRET` and `API_KEY` in environment variables or secure vaults
2. **Token expiration**: Access tokens expire after 3600 seconds (1 hour)
3. **HTTPS only**: All API calls must use HTTPS
4. **Rate limiting**: API Gateway enforces rate limits per usage plan
5. **API key rotation**: Rotate API keys regularly

## Troubleshooting

### 401 Unauthorized
- Check if token is expired (tokens last 1 hour)
- Verify token is included in Authorization header
- Ensure token format is: `Bearer <token>`

### 403 Forbidden
- Verify API key is included in x-api-key header
- Check if API key is valid and not revoked
- Ensure API key is associated with correct usage plan

### 400 Bad Request
- Validate query parameters match expected format
- Check Content-Type header for POST requests
- Verify request body structure matches schema

### 500 Internal Server Error
- Check CloudWatch logs for detailed error messages
- Verify all backend services are running
- Contact API support with correlation ID from response

## Support

For API support, contact:
- Email: api-support@iqq.com
- Documentation: See `docs/` directory
- CloudWatch Logs: `/aws/lambda/iqq-*-service-dev`

## Related Documentation

- [API Guide](./OPENAPI_GUIDE.md) - Original API documentation
- [Deployment Guide](../deployment/DEPLOYMENT_GUIDE.md) - Deployment instructions
- [Architecture](../architecture/PROJECT_STRUCTURE.md) - System architecture
