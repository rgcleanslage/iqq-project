# OpenAPI Documentation Guide

## Overview

The `openapi.yaml` file provides a complete OpenAPI 3.0 specification for the iQQ Insurance Quoting Platform API.

## What's Included

- Complete API endpoint documentation
- Request/response schemas with examples
- Authentication requirements (OAuth 2.0 + API Key)
- Error response formats
- Rate limiting information
- Correlation ID tracking

## Using the OpenAPI Spec

### 1. View in Swagger UI (Recommended)

**Online Viewer:**
1. Go to https://editor.swagger.io/
2. File → Import File → Select `openapi.yaml`
3. View interactive documentation with "Try it out" functionality

**Local Swagger UI:**
```bash
# Using Docker
docker run -p 8080:8080 -e SWAGGER_JSON=/openapi.yaml -v $(pwd):/usr/share/nginx/html swaggerapi/swagger-ui

# Open browser to http://localhost:8080
```

### 2. Generate Client SDKs

**Using OpenAPI Generator:**

```bash
# Install OpenAPI Generator
npm install @openapitools/openapi-generator-cli -g

# Generate TypeScript client
openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-axios \
  -o ./generated-clients/typescript

# Generate Python client
openapi-generator-cli generate \
  -i openapi.yaml \
  -g python \
  -o ./generated-clients/python

# Generate Java client
openapi-generator-cli generate \
  -i openapi.yaml \
  -g java \
  -o ./generated-clients/java
```

**Available generators:** typescript-axios, javascript, python, java, csharp, go, ruby, php, and 50+ more

### 3. Import into Postman

1. Open Postman
2. Import → Upload Files → Select `openapi.yaml`
3. Postman will create a collection with all endpoints
4. Configure authentication in collection settings:
   - OAuth 2.0: Add token URL and client credentials
   - API Key: Add `x-api-key` header

### 4. Import into Insomnia

1. Open Insomnia
2. Create → Import From → File
3. Select `openapi.yaml`
4. All endpoints will be imported with schemas

### 4a. Import into SoapUI

**Important:** Use the SoapUI-optimized version for best compatibility.

1. Open SoapUI
2. File → Import Project
3. Select `openapi-soapui.yaml` (not openapi.yaml)
4. SoapUI will create a REST project with all endpoints
5. Right-click on the project → Set Endpoint
6. Enter: `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev`
7. Add authentication headers to each request:
   - `Authorization: Bearer <token>`
   - `x-api-key: <your-api-key>`

**Alternative:** If endpoint is not set automatically:
1. After import, expand the project tree
2. Right-click on each endpoint (GET /lender, etc.)
3. Select "Set Endpoint"
4. Enter the full URL: `https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev`

### 5. API Documentation Website

**Using Redoc:**

```bash
# Install Redoc CLI
npm install -g redoc-cli

# Generate static HTML documentation
redoc-cli bundle openapi.yaml -o api-docs.html

# Open api-docs.html in browser
```

**Using Stoplight Elements:**

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>iQQ API Documentation</title>
  <script src="https://unpkg.com/@stoplight/elements/web-components.min.js"></script>
  <link rel="stylesheet" href="https://unpkg.com/@stoplight/elements/styles.min.css">
</head>
<body>
  <elements-api
    apiDescriptionUrl="./openapi.yaml"
    router="hash"
    layout="sidebar"
  />
</body>
</html>
```

### 6. Contract Testing

**Using Dredd:**

```bash
# Install Dredd
npm install -g dredd

# Run contract tests
dredd openapi.yaml https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev \
  --header "Authorization: Bearer YOUR_TOKEN" \
  --header "x-api-key: YOUR_API_KEY"
```

**Using Schemathesis:**

```bash
# Install Schemathesis
pip install schemathesis

# Run automated tests
schemathesis run openapi.yaml \
  --base-url https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev \
  --header "Authorization: Bearer YOUR_TOKEN" \
  --header "x-api-key: YOUR_API_KEY"
```

### 7. Mock Server

**Using Prism:**

```bash
# Install Prism
npm install -g @stoplight/prism-cli

# Start mock server
prism mock openapi.yaml

# API will be available at http://localhost:4010
```

## API Endpoints

### Lender Service
- **GET** `/lender?lenderId=LENDER-123`
- Returns lender information with contact details and ratings

### Package Service
- **GET** `/package?packageId=PKG-456`
- Returns insurance package bundles with pricing

### Product Service
- **GET** `/product?productId=PROD-789`
- Returns product details with coverage and providers

### Document Service
- **GET** `/document?documentId=DOC-101`
- Returns document metadata and download URLs

## Authentication

### OAuth 2.0 Token

```bash
curl -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "25oa5u3vup2jmhl270e7shudkl:oilctiluurgblk7212h8jb9lntjoefqb6n56rer3iuks9642el9" \
  -d "grant_type=client_credentials&scope=iqq-api/read iqq-api/write"
```

### API Key

Get your API key:
```bash
./get-api-keys.sh
```

### Making Authenticated Requests

```bash
# With both OAuth token and API key
curl -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev/lender?lenderId=LENDER-123" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "x-api-key: YOUR_API_KEY"
```

## Response Headers

All responses include:
- `X-Correlation-ID`: Unique request identifier for tracing
- `Content-Type`: application/json
- `Access-Control-Allow-Origin`: CORS header

## Error Responses

### 401 Unauthorized
```json
{
  "message": "Unauthorized"
}
```

### 403 Forbidden
```json
{
  "message": "Forbidden"
}
```

### 429 Too Many Requests
```json
{
  "message": "Too Many Requests"
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal Server Error",
  "message": "Failed to process request",
  "correlationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

## Rate Limits

### Standard Plan
- 10,000 requests per month
- 50 requests per second
- 100 burst limit

### Premium Plan
- 100,000 requests per month
- 200 requests per second
- 500 burst limit

## Validation

Validate your OpenAPI spec:

```bash
# Using Spectral
npm install -g @stoplight/spectral-cli
spectral lint openapi.yaml

# Using OpenAPI CLI
npm install -g @redocly/cli
redocly lint openapi.yaml
```

## Updating the Spec

When you add new endpoints or modify existing ones:

1. Update `openapi.yaml`
2. Validate the spec: `spectral lint openapi.yaml`
3. Regenerate documentation: `redoc-cli bundle openapi.yaml -o api-docs.html`
4. Update client SDKs if needed
5. Run contract tests to verify compatibility

## Best Practices

1. **Version Control**: Keep `openapi.yaml` in Git
2. **CI/CD Integration**: Validate spec in CI pipeline
3. **Breaking Changes**: Use API versioning for breaking changes
4. **Documentation**: Keep examples up-to-date with actual responses
5. **Security**: Never commit credentials in examples
6. **Testing**: Use contract testing to ensure API matches spec

## Tools Summary

| Tool | Purpose | Command |
|------|---------|---------|
| Swagger Editor | Interactive documentation | https://editor.swagger.io/ |
| Redoc | Static documentation | `redoc-cli bundle openapi.yaml` |
| OpenAPI Generator | Client SDK generation | `openapi-generator-cli generate` |
| Prism | Mock server | `prism mock openapi.yaml` |
| Dredd | Contract testing | `dredd openapi.yaml <url>` |
| Spectral | Spec validation | `spectral lint openapi.yaml` |

## Next Steps

1. ✅ View spec in Swagger Editor
2. Generate client SDKs for your preferred language
3. Import into Postman/Insomnia for testing
4. Generate static documentation website
5. Setup contract testing in CI/CD
6. Share documentation with API consumers

## Resources

- [OpenAPI Specification](https://swagger.io/specification/)
- [Swagger Editor](https://editor.swagger.io/)
- [OpenAPI Generator](https://openapi-generator.tech/)
- [Redoc](https://redocly.com/redoc/)
- [Prism Mock Server](https://stoplight.io/open-source/prism)
- [Spectral Linter](https://stoplight.io/open-source/spectral)

---

**Your OpenAPI spec is ready to use!** 🎉
