# API Version Headers Implementation

## Overview

This document describes the implementation of version headers in all API responses. Version headers provide clients with information about the API version they're using, deprecation status, and migration guidance.

## Task 3: Lambda Version Headers ✅

**Status**: Complete  
**Date**: February 18, 2026  
**Services Updated**: Package, Document, Lender, Product (All services)

## Implementation

### Response Headers

All API responses now include the following headers:

| Header | Type | Description | Example |
|--------|------|-------------|---------|
| `X-API-Version` | string | Current API version | `v1`, `v2` |
| `X-API-Deprecated` | boolean | Whether version is deprecated | `false`, `true` |
| `X-API-Sunset-Date` | string\|null | Sunset date (ISO 8601) or null | `2026-12-31T23:59:59Z` |
| `X-Correlation-ID` | string | Request correlation ID | UUID |
| `Warning` | string | Deprecation warning (if deprecated) | See below |

### Header Examples

#### Stable Version (v1)
```http
HTTP/2 200
Content-Type: application/json
X-API-Version: v1
X-API-Deprecated: false
X-API-Sunset-Date: null
X-Correlation-ID: 67e8e6ca-57df-4c81-809d-d88e064b4edb
Access-Control-Allow-Origin: *
```

#### Deprecated Version (example)
```http
HTTP/2 200
Content-Type: application/json
X-API-Version: v1
X-API-Deprecated: true
X-API-Sunset-Date: 2026-12-31T23:59:59Z
X-Correlation-ID: 67e8e6ca-57df-4c81-809d-d88e064b4edb
Warning: 299 - "API version v1 is deprecated. Please migrate to v2 by 2026-12-31. See https://docs.iqq.com/api/migration/v1-to-v2"
Access-Control-Allow-Origin: *
```

## Architecture

### Components Created

#### 1. Response Builder Utility

**File**: `src/utils/response-builder.ts` (in each service)

```typescript
import { APIGatewayProxyResult } from 'aws-lambda';
import versionPolicy from '../config/version-policy.json';

interface ResponseOptions {
  statusCode: number;
  body: any;
  correlationId: string;
  apiVersion: string;
}

export function buildVersionedResponse(options: ResponseOptions): APIGatewayProxyResult {
  const { statusCode, body, correlationId, apiVersion } = options;
  
  // Get version metadata from policy
  const versionMeta = versionPolicy.versions[apiVersion] || {
    status: 'unknown',
    sunsetDate: null,
    migrationGuide: null
  };
  
  // Build headers with version information
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-Correlation-ID': correlationId,
    'X-API-Version': apiVersion,
    'X-API-Deprecated': versionMeta.status === 'deprecated' ? 'true' : 'false',
    'X-API-Sunset-Date': versionMeta.sunsetDate || 'null',
    'Access-Control-Allow-Origin': '*'
  };
  
  // Add Warning header for deprecated versions
  if (versionMeta.status === 'deprecated' && versionMeta.sunsetDate) {
    const sunsetDate = new Date(versionMeta.sunsetDate).toISOString().split('T')[0];
    const currentVersion = versionPolicy.currentVersion;
    headers['Warning'] = `299 - "API version ${apiVersion} is deprecated. Please migrate to ${currentVersion} by ${sunsetDate}. See ${versionMeta.migrationGuide}"`;
  }
  
  return {
    statusCode,
    headers,
    body: JSON.stringify(body)
  };
}

export function getApiVersion(event: any): string {
  // Extract version from stage name
  return event.requestContext?.stage || 'v1';
}
```

**Features**:
- Automatic version detection from API Gateway stage
- Deprecation warning generation
- Consistent header format across all services
- Type-safe with TypeScript

#### 2. Version Policy Configuration

**File**: `src/config/version-policy.json` (in each service)

```json
{
  "currentVersion": "v1",
  "versions": {
    "v1": {
      "status": "stable",
      "sunsetDate": null,
      "migrationGuide": null
    },
    "v2": {
      "status": "planned",
      "sunsetDate": null,
      "migrationGuide": "https://docs.iqq.com/api/migration/v1-to-v2"
    }
  }
}
```

**Version Statuses**:
- `planned` - Version defined but not yet released
- `alpha` - Internal testing only
- `beta` - Selected partners
- `stable` - Production-ready
- `deprecated` - Scheduled for removal
- `sunset` - No longer supported

#### 3. Lambda Handler Updates

**Before**:
```typescript
export const handler = async (event: APIGatewayProxyEvent) => {
  const correlationId = event.requestContext.requestId;
  
  // ... business logic ...
  
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'X-Correlation-ID': correlationId,
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify(data)
  };
};
```

**After**:
```typescript
import { buildVersionedResponse, getApiVersion } from './utils/response-builder';

export const handler = async (event: APIGatewayProxyEvent) => {
  const correlationId = event.requestContext.requestId;
  const apiVersion = getApiVersion(event);
  
  // ... business logic ...
  
  return buildVersionedResponse({
    statusCode: 200,
    body: data,
    correlationId,
    apiVersion
  });
};
```

## Services Updated

### ✅ Package Service
- **Status**: Deployed and tested
- **Files Created**:
  - `iqq-package-service/src/utils/response-builder.ts`
  - `iqq-package-service/src/config/version-policy.json`
- **Handler Updated**: Yes
- **Test Results**: All headers present and correct

### ✅ Document Service
- **Status**: Deployed and tested
- **Files Created**:
  - `iqq-document-service/src/utils/response-builder.ts`
  - `iqq-document-service/src/config/version-policy.json`
- **Handler Updated**: Yes
- **Test Results**: All headers present and correct

### ✅ Lender Service
- **Status**: Deployed and tested
- **Files Created**:
  - `iqq-lender-service/src/utils/response-builder.ts`
  - `iqq-lender-service/src/config/version-policy.json`
- **Handler Updated**: Yes
- **Test Results**: All headers present and correct

### ✅ Product Service
- **Status**: Deployed and tested
- **Files Created**:
  - `iqq-product-service/src/utils/response-builder.ts`
  - `iqq-product-service/src/config/version-policy.json`
- **Handler Updated**: Yes
- **Test Results**: All headers present and correct

## Testing

### Test Results

#### v1 Package Endpoint
```bash
curl -i https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package?productCode=MBP
```

**Headers**:
```
x-api-version: v1
x-api-deprecated: false
x-api-sunset-date: null
x-correlation-id: 67e8e6ca-57df-4c81-809d-d88e064b4edb
```

#### v2 Package Endpoint
```bash
curl -i https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/package?productCode=MBP
```

**Headers**:
```
x-api-version: v2
x-api-deprecated: false
x-api-sunset-date: null
x-correlation-id: 02e24370-2987-4994-a880-222d3f529be4
```

#### v1 Lender Endpoint
```bash
curl -i https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/lender?lenderId=LENDER-001
```

**Headers**:
```
x-api-version: v1
x-api-deprecated: false
x-api-sunset-date: null
x-correlation-id: 34447e21-7c12-4f3f-859c-1f067e57f487
```

#### v2 Lender Endpoint
```bash
curl -i https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/lender?lenderId=LENDER-001
```

**Headers**:
```
x-api-version: v2
x-api-deprecated: false
x-api-sunset-date: null
x-correlation-id: 9c2df7c7-e0ac-4a0f-ac1f-f8678d2d9abf
```

#### v1 Product Endpoint
```bash
curl -i https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/product?productId=PROD-001
```

**Headers**:
```
x-api-version: v1
x-api-deprecated: false
x-api-sunset-date: null
x-correlation-id: f7806f0d-39f3-453f-99fe-be538886611f
```

#### v2 Product Endpoint
```bash
curl -i https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/product?productId=PROD-001
```

**Headers**:
```
x-api-version: v2
x-api-deprecated: false
x-api-sunset-date: null
x-correlation-id: eaf24976-5e2f-41b2-a153-2288724b44ea
```

#### v1 Document Endpoint
```bash
curl -i https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/document
```

**Headers**:
```
x-api-version: v1
x-api-deprecated: false
x-api-sunset-date: null
x-correlation-id: 24b3f9d9-c498-4433-8764-34c262d1b140
```

### Test Script

**File**: `scripts/test-all-version-headers.sh`

```bash
#!/bin/bash
# Test version headers across all four services
./scripts/test-all-version-headers.sh
```

## Client Usage

### Reading Version Headers

#### JavaScript/TypeScript
```typescript
const response = await fetch('https://api.iqq.com/v1/package', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'x-api-key': apiKey
  }
});

const apiVersion = response.headers.get('X-API-Version');
const isDeprecated = response.headers.get('X-API-Deprecated') === 'true';
const sunsetDate = response.headers.get('X-API-Sunset-Date');
const warning = response.headers.get('Warning');

if (isDeprecated) {
  console.warn(`API version ${apiVersion} is deprecated. Sunset: ${sunsetDate}`);
  console.warn(warning);
}
```

#### Python
```python
import requests

response = requests.get(
    'https://api.iqq.com/v1/package',
    headers={
        'Authorization': f'Bearer {token}',
        'x-api-key': api_key
    }
)

api_version = response.headers.get('X-API-Version')
is_deprecated = response.headers.get('X-API-Deprecated') == 'true'
sunset_date = response.headers.get('X-API-Sunset-Date')
warning = response.headers.get('Warning')

if is_deprecated:
    print(f'Warning: API version {api_version} is deprecated')
    print(f'Sunset date: {sunset_date}')
    print(warning)
```

#### cURL
```bash
curl -i https://api.iqq.com/v1/package \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" \
  | grep -E "^X-API-"
```

## Version Lifecycle Management

### Marking a Version as Deprecated

Update `src/config/version-policy.json` in each service:

```json
{
  "currentVersion": "v2",
  "versions": {
    "v1": {
      "status": "deprecated",
      "sunsetDate": "2026-12-31T23:59:59Z",
      "migrationGuide": "https://docs.iqq.com/api/migration/v1-to-v2"
    },
    "v2": {
      "status": "stable",
      "sunsetDate": null,
      "migrationGuide": null
    }
  }
}
```

**Result**: All v1 responses will include:
```
X-API-Deprecated: true
X-API-Sunset-Date: 2026-12-31T23:59:59Z
Warning: 299 - "API version v1 is deprecated. Please migrate to v2 by 2026-12-31. See https://docs.iqq.com/api/migration/v1-to-v2"
```

### Deployment Process

1. Update `version-policy.json` in service
2. Build service: `npm run build`
3. Deploy service: `sam build && sam deploy`
4. Verify headers: `curl -i <endpoint>`

## Benefits

### For Clients
- ✅ Know which version they're using
- ✅ Receive advance warning of deprecations
- ✅ Plan migrations with sunset dates
- ✅ Access migration guides directly from headers

### For Platform
- ✅ Track version adoption
- ✅ Communicate deprecations automatically
- ✅ Enforce version lifecycle policies
- ✅ Provide consistent versioning experience

### For Operations
- ✅ Monitor version usage in logs
- ✅ Identify clients on deprecated versions
- ✅ Track migration progress
- ✅ Automate deprecation warnings

## Monitoring

### CloudWatch Logs

Version information is now logged:
```json
{
  "correlationId": "67e8e6ca-57df-4c81-809d-d88e064b4edb",
  "apiVersion": "v1",
  "path": "/package",
  "method": "GET",
  "status": 200
}
```

### CloudWatch Insights Queries

**Requests by version**:
```sql
fields @timestamp, apiVersion, path, status
| stats count() by apiVersion
```

**Deprecated version usage**:
```sql
fields @timestamp, apiVersion, path
| filter apiVersion = "v1"
| stats count() by bin(1h)
```

## Next Steps

1. ✅ **Complete Remaining Services**: All four services (package, lender, product, document) now have version headers implemented and deployed

2. **Update Documentation**:
   - Update OpenAPI specs with version headers
   - Update Postman collections to show headers
   - Create migration guides

3. **Implement Monitoring**:
   - Create CloudWatch dashboard for version metrics
   - Set up alerts for deprecated version usage
   - Track migration progress

4. **Proceed to Task 4**: Set up centralized GitHub Actions workflows for version deployment orchestration

## References

- [API Versioning Requirements](../../.kiro/specs/api-versioning/requirements.md)
- [API Versioning Design](../../.kiro/specs/api-versioning/design.md)
- [API Versioning Tasks](../../.kiro/specs/api-versioning/tasks.md)
- [Terraform Implementation](../deployment/API_VERSIONING_TERRAFORM.md)
- [Deployment Results](../deployment/API_VERSIONING_DEPLOYMENT_RESULTS.md)
- [RFC 7234 - HTTP Warning Header](https://tools.ietf.org/html/rfc7234#section-5.5)

---

**Task Status**: ✅ Complete (All four services)  
**Completed**: February 18, 2026  
**Next Task**: Task 4 - Set up centralized GitHub Actions workflows
