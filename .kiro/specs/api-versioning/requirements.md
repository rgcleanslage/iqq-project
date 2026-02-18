# API Versioning Requirements

## Overview
Implement a robust API versioning strategy for the iQQ Insurance Quoting Platform API Gateway to support backward compatibility, gradual migrations, and multiple API versions in production.

## Business Context
- **Current State**: Single API version deployed to `/dev` stage with Lambda aliases (v1, v2)
- **Problem**: No clear versioning strategy for clients; breaking changes would affect all users
- **Goal**: Enable multiple API versions to coexist, allowing clients to migrate at their own pace

## User Stories

### US-1: As an API consumer, I want to specify which API version I'm using
**Acceptance Criteria**:
- AC-1.1: I can access different API versions via URL path (e.g., `/v1/package`, `/v2/package`)
- AC-1.2: I can access different API versions via custom header (e.g., `X-API-Version: v1`)
- AC-1.3: If I don't specify a version, I get the latest stable version
- AC-1.4: I receive clear error messages if I request an unsupported version

### US-2: As a platform operator, I want to deploy new API versions without breaking existing clients
**Acceptance Criteria**:
- AC-2.1: Multiple API versions can run simultaneously
- AC-2.2: Each version can point to different Lambda function versions/aliases
- AC-2.3: I can deprecate old versions with a sunset timeline
- AC-2.4: I can monitor usage per API version

### US-3: As a platform operator, I want to gradually migrate clients to new versions
**Acceptance Criteria**:
- AC-3.1: I can see which clients are using which API versions
- AC-3.2: I can send deprecation warnings in API responses
- AC-3.3: I can set a sunset date for old versions
- AC-3.4: I can route specific clients to specific versions (canary/beta testing)

### US-4: As a developer, I want clear documentation on version differences
**Acceptance Criteria**:
- AC-4.1: Each version has documented breaking changes
- AC-4.2: Migration guides exist between versions
- AC-4.3: OpenAPI spec includes version information
- AC-4.4: Changelog is maintained for each version

## Versioning Strategy Options

### Option 1: URL Path Versioning (Recommended)
**Format**: `https://api.example.com/v1/package`

**Pros**:
- ✅ Most explicit and visible
- ✅ Easy to cache and route
- ✅ Works with all HTTP clients
- ✅ Clear in logs and monitoring
- ✅ Industry standard (Stripe, Twilio, AWS)

**Cons**:
- ❌ Requires more API Gateway resources
- ❌ URL structure changes

**Implementation**:
```
/v1/package → Lambda:iqq-package-service:v1
/v1/lender  → Lambda:iqq-lender-service:v1
/v2/package → Lambda:iqq-package-service:v2
/v2/lender  → Lambda:iqq-lender-service:v2
```

### Option 2: Header-Based Versioning
**Format**: `X-API-Version: v1` or `Accept: application/vnd.iqq.v1+json`

**Pros**:
- ✅ Clean URLs
- ✅ RESTful approach
- ✅ Flexible versioning

**Cons**:
- ❌ Less visible (hidden in headers)
- ❌ Harder to test in browser
- ❌ Requires custom routing logic
- ❌ Caching complexity

### Option 3: Query Parameter Versioning
**Format**: `https://api.example.com/package?version=v1`

**Pros**:
- ✅ Simple to implement
- ✅ No URL structure changes

**Cons**:
- ❌ Not RESTful
- ❌ Easy to forget
- ❌ Caching issues
- ❌ Not recommended by industry

### Option 4: Subdomain Versioning
**Format**: `https://v1.api.example.com/package`

**Pros**:
- ✅ Clear separation
- ✅ Easy to route at DNS level

**Cons**:
- ❌ Requires DNS management
- ❌ SSL certificate complexity
- ❌ Overkill for our use case

## Recommended Approach: URL Path Versioning

### Architecture Design

#### Current Structure
```
API Gateway: iqq-api-dev
├── /dev/package  → iqq-package-service:v1
├── /dev/lender   → iqq-lender-service:v1
├── /dev/product  → iqq-product-service:v1
└── /dev/document → iqq-document-service:v1
```

#### Proposed Structure
```
API Gateway: iqq-api-dev
├── /v1/package  → iqq-package-service:v1
├── /v1/lender   → iqq-lender-service:v1
├── /v1/product  → iqq-product-service:v1
├── /v1/document → iqq-document-service:v1
├── /v2/package  → iqq-package-service:v2
├── /v2/lender   → iqq-lender-service:v2
├── /v2/product  → iqq-product-service:v2
└── /v2/document → iqq-document-service:v2
```

### Version Lifecycle

#### Phase 1: Development (Alpha)
- Version: `v2-alpha`
- Audience: Internal testing only
- Stability: Breaking changes allowed
- Support: None

#### Phase 2: Beta
- Version: `v2-beta`
- Audience: Selected partners
- Stability: Minimal breaking changes
- Support: Best effort

#### Phase 3: Stable
- Version: `v2`
- Audience: All clients
- Stability: No breaking changes
- Support: Full support

#### Phase 4: Deprecated
- Version: `v1` (after v2 is stable)
- Audience: Legacy clients
- Stability: Frozen (no new features)
- Support: Security fixes only
- Timeline: 6-12 months until sunset

#### Phase 5: Sunset
- Version: `v1` (end of life)
- Audience: None (forced migration)
- Stability: N/A
- Support: None

## Version Compatibility Matrix

| Version | Status | Lambda Alias | Sunset Date | Breaking Changes |
|---------|--------|--------------|-------------|------------------|
| v1 | Stable | v1 | TBD | N/A (baseline) |
| v2 | Planned | v2 | N/A | TBD |

## Breaking vs Non-Breaking Changes

### Breaking Changes (Require New Version)
- Removing endpoints
- Removing request/response fields
- Changing field types
- Changing authentication methods
- Changing error response formats
- Renaming fields

### Non-Breaking Changes (Same Version)
- Adding new endpoints
- Adding optional request fields
- Adding response fields
- Adding new error codes
- Performance improvements
- Bug fixes

## Implementation Considerations

### 1. API Gateway Resources
**Current**: 4 resources (package, lender, product, document)
**Proposed**: 8 resources (v1/* and v2/*)

**Impact**: Minimal cost increase, better organization

### 2. Lambda Aliases
**Current**: Already using aliases (v1, v2, latest)
**Proposed**: Continue using aliases, map to API versions

**Impact**: No change needed

### 3. Client Migration
**Strategy**: 
- Announce v2 with 3-month notice
- Provide migration guide
- Send deprecation warnings in v1 responses
- Set sunset date for v1
- Monitor usage and reach out to stragglers

### 4. Monitoring & Analytics
**Metrics to Track**:
- Requests per version
- Clients per version
- Error rates per version
- Response times per version
- Deprecation warning delivery

### 5. Documentation
**Required**:
- Version-specific OpenAPI specs
- Migration guides (v1 → v2)
- Changelog per version
- Deprecation notices
- Version support policy

## Technical Requirements

### TR-1: API Gateway Configuration
- Create versioned resource paths (`/v1/*`, `/v2/*`)
- Map versions to Lambda aliases
- Configure stage variables for version routing
- Set up custom domain with versioned paths

### TR-2: Lambda Function Updates
- Ensure all functions support versioning
- Add version info to response headers
- Implement version-specific logic if needed
- Maintain backward compatibility in v1

### TR-3: Response Headers
All responses should include:
```
X-API-Version: v1
X-API-Deprecated: false
X-API-Sunset-Date: null
```

For deprecated versions:
```
X-API-Version: v1
X-API-Deprecated: true
X-API-Sunset-Date: 2026-12-31
Warning: 299 - "API version v1 is deprecated. Please migrate to v2. See https://docs.iqq.com/migration"
```

### TR-4: Error Responses
Version not found:
```json
{
  "error": "UnsupportedVersion",
  "message": "API version 'v3' is not supported",
  "supportedVersions": ["v1", "v2"],
  "currentVersion": "v2",
  "documentation": "https://docs.iqq.com/versioning"
}
```

### TR-5: Default Version Behavior
- If no version specified in path: Use latest stable (v2)
- If version specified but not found: Return 404 with supported versions
- If version deprecated: Return 200 with deprecation headers

## Migration Path

### Phase 1: Preparation (Week 1-2)
1. Update Terraform to create versioned resources
2. Update Lambda integrations to use aliases
3. Add version headers to responses
4. Update documentation

### Phase 2: Deploy v1 (Week 3)
1. Deploy current API as `/v1/*`
2. Keep `/dev/*` as alias to `/v1/*` (backward compatibility)
3. Test all endpoints
4. Update Postman collection

### Phase 3: Develop v2 (Week 4-8)
1. Implement v2 changes in Lambda functions
2. Deploy to v2 alias
3. Create `/v2/*` resources
4. Beta test with selected clients

### Phase 4: Promote v2 (Week 9)
1. Mark v2 as stable
2. Update default version to v2
3. Announce v1 deprecation
4. Provide migration guide

### Phase 5: Sunset v1 (Month 6-12)
1. Monitor v1 usage
2. Contact remaining v1 clients
3. Set sunset date
4. Remove v1 resources

## Success Metrics

### Adoption Metrics
- % of clients on latest version
- Time to migrate (average)
- Migration completion rate

### Quality Metrics
- Error rate per version
- Response time per version
- Breaking change incidents

### Business Metrics
- Client satisfaction with versioning
- Support tickets related to versioning
- API downtime during version deployments

## Risks & Mitigation

### Risk 1: Increased Complexity
**Impact**: High
**Probability**: High
**Mitigation**: 
- Clear documentation
- Automated testing per version
- Version-specific monitoring

### Risk 2: Client Confusion
**Impact**: Medium
**Probability**: Medium
**Mitigation**:
- Clear communication
- Migration guides
- Deprecation warnings
- Support during migration

### Risk 3: Maintenance Burden
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Limit supported versions (max 2)
- Aggressive sunset timelines
- Automated testing
- Shared code between versions

### Risk 4: Breaking Changes in v1
**Impact**: High
**Probability**: Low
**Mitigation**:
- Freeze v1 after v2 launch
- Only security fixes in v1
- Comprehensive testing

## Open Questions

1. **Q**: Should we support more than 2 versions simultaneously?
   **A**: No, maximum 2 versions (current stable + previous deprecated)

2. **Q**: How long should we support deprecated versions?
   **A**: 6-12 months depending on client adoption

3. **Q**: Should we version the entire API or per-endpoint?
   **A**: Entire API for consistency

4. **Q**: What about internal/admin endpoints?
   **A**: Follow same versioning strategy

5. **Q**: How do we handle Step Functions and provider integrations?
   **A**: Version-agnostic; internal services don't need versioning

## Dependencies

- Terraform (API Gateway configuration)
- Lambda aliases (already implemented)
- Documentation updates
- Client communication plan
- Monitoring/analytics setup

## Out of Scope

- Semantic versioning (v1.2.3) - too granular
- Per-endpoint versioning - too complex
- Automatic version negotiation - unnecessary
- Version in request body - not RESTful

## References

- [AWS API Gateway Versioning Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-versioning.html)
- [Stripe API Versioning](https://stripe.com/docs/api/versioning)
- [Twilio API Versioning](https://www.twilio.com/docs/glossary/what-is-api-versioning)
- [REST API Versioning Strategies](https://restfulapi.net/versioning/)

## Next Steps

1. Review and approve this requirements document
2. Create design document with detailed implementation plan
3. Create tasks for implementation
4. Begin Phase 1 (Preparation)

---

**Document Version**: 1.0
**Created**: February 18, 2026
**Last Updated**: February 18, 2026
**Status**: Draft - Awaiting Review
