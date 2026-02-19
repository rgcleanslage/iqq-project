# Migration Guide: v1 to v3

**Date**: February 19, 2026  
**Status**: Draft

## Overview

This guide helps you migrate from API version v1 to v3.

## What's New in v3

### New Features

- [ ] TODO: Document new features
- [ ] TODO: Document new endpoints
- [ ] TODO: Document new parameters

### Improvements

- [ ] TODO: Document performance improvements
- [ ] TODO: Document enhanced functionality

### Bug Fixes

- [ ] TODO: Document bug fixes

## Breaking Changes

### ⚠️ Important Changes

> **Note**: Update this section with any breaking changes between v1 and v3

#### 1. [Breaking Change Title]

**What changed:**
- TODO: Describe the change

**Migration required:**
- TODO: Describe what clients need to do

**Before (v1):**
\`\`\`json
{
  "example": "old format"
}
\`\`\`

**After (v3):**
\`\`\`json
{
  "example": "new format"
}
\`\`\`

## Deprecated Features

The following features are deprecated in v3 and will be removed in a future version:

- [ ] TODO: List deprecated features

## Migration Steps

### Step 1: Review Breaking Changes

Review all breaking changes listed above and assess impact on your integration.

### Step 2: Update API Endpoints

Update your API endpoint URLs from v1 to v3:

**Before:**
\`\`\`
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package
\`\`\`

**After:**
\`\`\`
https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package
\`\`\`

### Step 3: Update Request/Response Handling

Update your code to handle any changes in request or response formats.

### Step 4: Test in Development

Test your integration thoroughly in a development environment:

\`\`\`bash
# Test package endpoint
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package?productCode=MBP" \\
  -H "Authorization: Bearer \$TOKEN" \\
  -H "x-api-key: \$API_KEY"

# Test lender endpoint
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/lender?lenderId=LENDER-001" \\
  -H "Authorization: Bearer \$TOKEN" \\
  -H "x-api-key: \$API_KEY"

# Test product endpoint
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/product?productId=PROD-001" \\
  -H "Authorization: Bearer \$TOKEN" \\
  -H "x-api-key: \$API_KEY"

# Test document endpoint
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/document" \\
  -H "Authorization: Bearer \$TOKEN" \\
  -H "x-api-key: \$API_KEY"
\`\`\`

### Step 5: Monitor Version Headers

Verify that you're receiving the correct version headers:

\`\`\`bash
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package?productCode=MBP" \\
  -H "Authorization: Bearer \$TOKEN" \\
  -H "x-api-key: \$API_KEY" | grep -i "x-api-version"

# Should return: x-api-version: v3
\`\`\`

### Step 6: Deploy to Production

Once testing is complete, deploy your changes to production.

## Code Examples

### JavaScript/TypeScript

**Before (v1):**
\`\`\`typescript
const response = await fetch(
  'https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package',
  {
    headers: {
      'Authorization': \`Bearer \${token}\`,
      'x-api-key': apiKey
    }
  }
);
\`\`\`

**After (v3):**
\`\`\`typescript
const response = await fetch(
  'https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package',
  {
    headers: {
      'Authorization': \`Bearer \${token}\`,
      'x-api-key': apiKey
    }
  }
);

// Check version headers
const apiVersion = response.headers.get('X-API-Version');
console.log('API Version:', apiVersion); // Should be: v3
\`\`\`

### Python

**Before (v1):**
\`\`\`python
import requests

response = requests.get(
    'https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package',
    headers={
        'Authorization': f'Bearer {token}',
        'x-api-key': api_key
    }
)
\`\`\`

**After (v3):**
\`\`\`python
import requests

response = requests.get(
    'https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package',
    headers={
        'Authorization': f'Bearer {token}',
        'x-api-key': api_key
    }
)

# Check version headers
api_version = response.headers.get('X-API-Version')
print(f'API Version: {api_version}')  # Should be: v3
\`\`\`

### cURL

**Before (v1):**
\`\`\`bash
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package?productCode=MBP" \\
  -H "Authorization: Bearer \$TOKEN" \\
  -H "x-api-key: \$API_KEY"
\`\`\`

**After (v3):**
\`\`\`bash
curl "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package?productCode=MBP" \\
  -H "Authorization: Bearer \$TOKEN" \\
  -H "x-api-key: \$API_KEY"
\`\`\`

## API Endpoints

All endpoints are available in v3:

| Endpoint | v1 URL | v3 URL |
|----------|---------------------|----------------|
| Package | \`/v1/package\` | \`/v3/package\` |
| Lender | \`/v1/lender\` | \`/v3/lender\` |
| Product | \`/v1/product\` | \`/v3/product\` |
| Document | \`/v1/document\` | \`/v3/document\` |

## Version Headers

v3 includes the following version headers in all responses:

| Header | Description | Example |
|--------|-------------|---------|
| \`X-API-Version\` | Current API version | \`v3\` |
| \`X-API-Deprecated\` | Whether version is deprecated | \`false\` |
| \`X-API-Sunset-Date\` | Sunset date (if deprecated) | \`null\` |
| \`X-Correlation-ID\` | Request correlation ID | UUID |

## Rollback Plan

If you encounter issues with v3, you can rollback to v1:

1. Update your endpoint URLs back to \`/v1/\`
2. Revert any code changes specific to v3
3. Monitor your application for stability
4. Report issues to the API team

## Support

If you need help with migration:

- **Documentation**: https://docs.iqq.com/api
- **API Reference**: https://docs.iqq.com/api/reference
- **Support Email**: api-support@iqq.com
- **GitHub Issues**: https://github.com/rgcleanslage/iqq-project/issues

## Timeline

- **v3 Release**: TODO: Add release date
- **v1 Deprecation**: TODO: Add deprecation date (if applicable)
- **v1 Sunset**: TODO: Add sunset date (if applicable)

## Checklist

Use this checklist to track your migration progress:

- [ ] Review breaking changes
- [ ] Update endpoint URLs
- [ ] Update request/response handling
- [ ] Test in development environment
- [ ] Verify version headers
- [ ] Update monitoring/logging
- [ ] Update documentation
- [ ] Deploy to staging
- [ ] Perform integration tests
- [ ] Deploy to production
- [ ] Monitor for issues

## Additional Resources

- [API Versioning Guide](../API_VERSIONING_SETUP.md)
- [Version Headers Documentation](../API_VERSION_HEADERS.md)
- [OpenAPI Specification](../openapi-complete.yaml)
- [Postman Collection](../postman-collection.json)

---

**Last Updated**: February 19, 2026  
**Status**: Draft - Please update with actual changes
