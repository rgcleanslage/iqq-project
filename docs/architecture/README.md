# Architecture Documentation

Complete architecture documentation for the iQQ Insurance Quoting Platform.

## Quick Start

### System Overview
1. [SYSTEM_ARCHITECTURE_DIAGRAM.md](./SYSTEM_ARCHITECTURE_DIAGRAM.md) - Complete system architecture
2. [ARCHITECTURE_VISUAL.md](./ARCHITECTURE_VISUAL.md) - Visual representations
3. [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - Project organization

### Component Details
1. [ADAPTER_ARCHITECTURE.md](./ADAPTER_ARCHITECTURE.md) - CSV/XML adapters
2. [DYNAMODB_SINGLE_TABLE_DESIGN.md](./DYNAMODB_SINGLE_TABLE_DESIGN.md) - Database design
3. [CLIENT_PREFERENCES_GUIDE.md](./CLIENT_PREFERENCES_GUIDE.md) - Client preferences system

## Documentation Index

### System Architecture
- **[SYSTEM_ARCHITECTURE_DIAGRAM.md](./SYSTEM_ARCHITECTURE_DIAGRAM.md)** - Complete system architecture with diagrams
- **[ARCHITECTURE_VISUAL.md](./ARCHITECTURE_VISUAL.md)** - Visual architecture representations
- **[PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)** - Project structure and organization

### Component Architecture
- **[ADAPTER_ARCHITECTURE.md](./ADAPTER_ARCHITECTURE.md)** - CSV/XML adapter design and implementation
- **[PATH_BASED_ACCESS_CONTROL_GUIDE.md](./PATH_BASED_ACCESS_CONTROL_GUIDE.md)** - Path-based access control
- **[API_KEY_CLIENT_MAPPING.md](./API_KEY_CLIENT_MAPPING.md)** - API key to client ID mapping

### Data Architecture
- **[DYNAMODB_SINGLE_TABLE_DESIGN.md](./DYNAMODB_SINGLE_TABLE_DESIGN.md)** - DynamoDB single-table design

### Client Preferences
- **[CLIENT_PREFERENCES_README.md](./CLIENT_PREFERENCES_README.md)** - Quick start guide
- **[CLIENT_PREFERENCES_GUIDE.md](./CLIENT_PREFERENCES_GUIDE.md)** - Complete documentation
- **[CLIENT_PREFERENCES_IMPLEMENTATION.md](./CLIENT_PREFERENCES_IMPLEMENTATION.md)** - Implementation details

## System Overview

The iQQ platform is a serverless microservices architecture built on AWS, designed for insurance quote aggregation with multi-provider support and API versioning.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     API Gateway (REST)                       │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐  │
│  │ /v1/*    │ /v2/*    │ /v3/*    │ /v4/*    │ /v5-v9/* │  │
│  └────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┘  │
└───────┼──────────┼──────────┼──────────┼──────────┼────────┘
        │          │          │          │          │
        └──────────┴──────────┴──────────┴──────────┘
                            │
                    ┌───────▼────────┐
                    │  Custom TOKEN  │
                    │   Authorizer   │
                    │ (OAuth + API)  │
                    └───────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼────┐      ┌──────▼──────┐     ┌─────▼─────┐
   │ Lender  │      │   Package   │     │  Product  │
   │ Service │      │   Service   │     │  Service  │
   │ (v1-v9) │      │   (v1-v9)   │     │  (v1-v9)  │
   └─────────┘      └──────┬──────┘     └───────────┘
                           │
                    ┌──────▼──────┐
                    │    Step     │
                    │  Functions  │
                    │Orchestration│
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐      ┌─────▼─────┐     ┌─────▼─────┐
   │Provider │      │ Provider  │     │ Provider  │
   │   APCO  │      │  Client   │     │ Route 66  │
   │  (HTTP) │      │  (HTTP)   │     │  (HTTP)   │
   └────┬────┘      └─────┬─────┘     └─────┬─────┘
        │                 │                  │
   ┌────▼────┐      ┌────▼────┐       ┌────▼────┐
   │Adapter  │      │Adapter  │       │  JSON   │
   │  CSV    │      │  XML    │       │ (direct)│
   └─────────┘      └─────────┘       └─────────┘
```

## Core Components

### 1. API Gateway
- **Purpose:** REST API entry point with versioning
- **Features:**
  - Multiple stages (v1-v9)
  - Custom TOKEN authorizer
  - Usage plans and API keys
  - Request/response transformation
- **Documentation:** [SYSTEM_ARCHITECTURE_DIAGRAM.md](./SYSTEM_ARCHITECTURE_DIAGRAM.md)

### 2. Lambda Functions
- **Services:** Package, Lender, Product, Document
- **Features:**
  - Version aliases (v1-v9)
  - ARM64 architecture
  - 512MB memory
  - TypeScript/Node.js 20.x
- **Documentation:** [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)

### 3. Step Functions
- **Purpose:** Orchestrate multi-provider quotes
- **Features:**
  - Parallel provider invocation
  - Error handling per provider
  - Retry logic
  - Result aggregation
- **Documentation:** [SYSTEM_ARCHITECTURE_DIAGRAM.md](./SYSTEM_ARCHITECTURE_DIAGRAM.md)

### 4. Cognito
- **Purpose:** OAuth 2.0 authentication
- **Features:**
  - Client credentials flow
  - Multiple app clients
  - JWT token generation
  - 1-hour token expiration
- **Documentation:** [API_KEY_CLIENT_MAPPING.md](./API_KEY_CLIENT_MAPPING.md)

### 5. DynamoDB
- **Purpose:** Provider configuration and client preferences
- **Features:**
  - Single-table design
  - On-demand billing
  - Provider metadata
  - Client preferences
- **Documentation:** [DYNAMODB_SINGLE_TABLE_DESIGN.md](./DYNAMODB_SINGLE_TABLE_DESIGN.md)

## Key Design Patterns

### 1. API Versioning
- **Pattern:** URL path versioning with Lambda aliases
- **Implementation:**
  - Each version is an API Gateway stage
  - Lambda aliases route to specific versions
  - GitHub Releases store version metadata
- **Benefits:**
  - Multiple versions in production
  - Independent version lifecycle
  - Gradual migration support

### 2. Adapter Pattern
- **Pattern:** Generic format adapters for provider responses
- **Implementation:**
  - CSV adapter for tabular data
  - XML adapter for structured data
  - Configuration-driven field mapping
- **Benefits:**
  - Reusable across providers
  - Easy to add new formats
  - Consistent output format
- **Documentation:** [ADAPTER_ARCHITECTURE.md](./ADAPTER_ARCHITECTURE.md)

### 3. Single-Table Design
- **Pattern:** DynamoDB single-table design
- **Implementation:**
  - Composite keys (PK, SK)
  - Entity types: PROVIDER, CLIENT_PREF
  - GSI for queries
- **Benefits:**
  - Reduced costs
  - Better performance
  - Simplified queries
- **Documentation:** [DYNAMODB_SINGLE_TABLE_DESIGN.md](./DYNAMODB_SINGLE_TABLE_DESIGN.md)

### 4. Client Preferences
- **Pattern:** Dynamic provider filtering per client
- **Implementation:**
  - Client preferences stored in DynamoDB
  - Runtime filtering in Package Service
  - Fallback to all providers
- **Benefits:**
  - Client-specific provider lists
  - No code changes needed
  - Easy preference management
- **Documentation:** [CLIENT_PREFERENCES_GUIDE.md](./CLIENT_PREFERENCES_GUIDE.md)

### 5. Orchestration Pattern
- **Pattern:** Step Functions for multi-provider orchestration
- **Implementation:**
  - Map state for parallel invocation
  - Error handling per provider
  - Result aggregation
- **Benefits:**
  - Scalable parallel processing
  - Resilient to provider failures
  - Visual workflow monitoring

## Technology Stack

### AWS Services
- **Compute:** Lambda (ARM64, Node.js 20.x)
- **API:** API Gateway (REST)
- **Orchestration:** Step Functions
- **Authentication:** Cognito
- **Database:** DynamoDB
- **Monitoring:** CloudWatch, X-Ray
- **Secrets:** Secrets Manager

### Development Tools
- **Language:** TypeScript
- **Runtime:** Node.js 20.x
- **Testing:** Jest
- **Deployment:** AWS SAM, Terraform
- **CI/CD:** GitHub Actions
- **Version Control:** Git, GitHub

### Infrastructure as Code
- **Lambda Services:** AWS SAM
- **Infrastructure:** Terraform
- **Versioning:** GitHub Releases
- **Automation:** GitHub Actions

## Security Architecture

### Authentication Flow
```
1. Client → Cognito OAuth endpoint
2. Cognito validates credentials
3. Cognito returns JWT access token
4. Client → API Gateway with token + API key
5. Custom authorizer validates token + API key
6. API Gateway → Lambda function
7. Lambda → Response with version metadata
```

### Security Layers
1. **OAuth 2.0** - JWT token validation
2. **API Keys** - Required for all requests
3. **Custom Authorizer** - Validates both token and key
4. **Secrets Manager** - Secure credential storage
5. **IAM Roles** - Least privilege access
6. **VPC** - Optional network isolation

### Security Best Practices
- No secrets in git repository
- AWS Secrets Manager for credentials
- GitHub OIDC for CI/CD (no long-lived credentials)
- Regular credential rotation
- Least privilege IAM policies

## Data Flow

### Quote Request Flow
```
1. Client authenticates with Cognito
2. Client calls /v1/package with OAuth token + API key
3. API Gateway validates via custom authorizer
4. Package Service receives request
5. Package Service loads client preferences from DynamoDB
6. Package Service loads provider config from DynamoDB
7. Package Service filters providers based on preferences
8. Package Service invokes Step Functions
9. Step Functions invokes providers in parallel
10. Providers return quotes (CSV/XML/JSON)
11. Adapters transform to JSON
12. Step Functions aggregates results
13. Package Service calculates best quote
14. Package Service returns response with version metadata
```

### Version Metadata Flow
```
1. GitHub Release stores version metadata
2. Lambda environment variables set during deployment
3. Response builder reads env vars
4. Metadata included in all API responses
5. Deprecation headers added if version deprecated
```

## Scalability

### Horizontal Scaling
- **Lambda:** Auto-scales to 1000 concurrent executions
- **API Gateway:** Handles 10,000 requests/second
- **DynamoDB:** On-demand scaling
- **Step Functions:** 1 million state transitions/month

### Performance Optimization
- **ARM64:** 20% better price-performance
- **Right-sized Memory:** 512MB for most functions
- **Parallel Processing:** Step Functions map state
- **Caching:** API Gateway response caching (optional)

### Cost Optimization
- **On-demand Billing:** Pay only for usage
- **ARM64 Architecture:** 20% cheaper
- **7-day Log Retention:** Reduced storage costs
- **No Provisioned Concurrency:** No idle costs

## Monitoring & Observability

### CloudWatch Logs
- Structured JSON logging
- Correlation ID tracking
- 7-day retention
- Log groups per function

### X-Ray Tracing
- End-to-end request tracing
- Service map visualization
- Performance analysis
- Error tracking

### CloudWatch Metrics
- Lambda: invocations, duration, errors
- API Gateway: requests, latency, 4xx/5xx
- Step Functions: executions, success/failure
- DynamoDB: read/write capacity

## Related Documentation

### Deployment
- [Deployment Guide](../deployment/DEPLOYMENT_GUIDE.md)
- [API Versioning](../deployment/API_VERSIONING_WITH_GITHUB_RELEASES.md)
- [CI/CD Setup](../deployment/CICD_SETUP_GUIDE.md)

### API
- [API Documentation](../api/README.md)
- [OpenAPI Specification](../api/openapi-complete.yaml)
- [Version Headers](../api/API_VERSION_HEADERS.md)

### Testing
- [Testing Guide](../testing/README.md)
- [SoapUI Testing](../testing/SOAPUI_TESTING_GUIDE.md)

---

**Last Updated:** February 19, 2026  
**Architecture Version:** 2.0  
**Status:** Production Ready ✅
