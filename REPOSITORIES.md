# iQQ Platform Repositories

The iQQ Insurance Quoting Platform is split into 7 GitHub repositories for better modularity and independent deployment.

## Repository Structure

### 0. iqq-project (Main Documentation)
**Repository:** https://github.com/rgcleanslage/iqq-project  
**Purpose:** Project-wide documentation, scripts, and architecture  
**Contains:** 
- Project README and overview
- Architecture documentation
- Deployment guides
- Testing documentation
- API specifications (OpenAPI)
- Utility scripts (deployment, testing, seeding)
- Reference materials

**Deploy First:** No (documentation and scripts only)

---

### 1. iqq-infrastructure
**Repository:** https://github.com/rgcleanslage/iqq-infrastructure  
**Purpose:** Terraform infrastructure as code  
**Contains:** 
- API Gateway configuration
- Cognito User Pool setup
- DynamoDB tables
- Step Functions state machines
- Lambda versioning and aliases
- IAM roles and policies

**Deploy First:** No (deploy Lambda functions first)

---

### 2. iqq-providers
**Repository:** https://github.com/rgcleanslage/iqq-providers  
**Purpose:** Provider integration services  
**Contains:**
- CSV Adapter (generic CSV to JSON transformer)
- XML Adapter (generic XML to JSON transformer)
- Client Provider (CSV format)
- Route 66 Provider (JSON format)
- APCO Provider (XML format)
- Provider Loader (DynamoDB query)
- OAuth + API Key Authorizer

**Deploy First:** Yes (required by infrastructure)

---

### 3. iqq-lender-service
**Repository:** https://github.com/rgcleanslage/iqq-lender-service  
**Purpose:** Lender microservice  
**Contains:**
- Lender information API
- TypeScript Lambda function
- Unit tests with Jest
- SAM deployment configuration

**Deploy First:** Yes (required by infrastructure)

---

### 4. iqq-package-service
**Repository:** https://github.com/rgcleanslage/iqq-package-service  
**Purpose:** Package microservice with quote orchestration  
**Contains:**
- Package API with Step Functions integration
- Multi-provider quote aggregation
- TypeScript Lambda function
- Unit tests with Jest (mocked Step Functions)
- SAM deployment configuration

**Deploy First:** Yes (required by infrastructure)

---

### 5. iqq-product-service
**Repository:** https://github.com/rgcleanslage/iqq-product-service  
**Purpose:** Product microservice  
**Contains:**
- Product information API
- TypeScript Lambda function
- Unit tests with Jest
- SAM deployment configuration

**Deploy First:** Yes (required by infrastructure)

---

### 6. iqq-document-service
**Repository:** https://github.com/rgcleanslage/iqq-document-service  
**Purpose:** Document microservice  
**Contains:**
- Document information API
- TypeScript Lambda function
- Unit tests with Jest
- SAM deployment configuration

**Deploy First:** Yes (required by infrastructure)

---

## Deployment Order

**Critical:** Deploy in this order to avoid dependency issues:

1. **Deploy all Lambda services first** (repos 2-6):
   ```bash
   # Clone and deploy each service
   git clone https://github.com/rgcleanslage/iqq-providers.git
   cd iqq-providers && sam build && sam deploy
   
   git clone https://github.com/rgcleanslage/iqq-lender-service.git
   cd iqq-lender-service && sam build && sam deploy
   
   git clone https://github.com/rgcleanslage/iqq-package-service.git
   cd iqq-package-service && sam build && sam deploy
   
   git clone https://github.com/rgcleanslage/iqq-product-service.git
   cd iqq-product-service && sam build && sam deploy
   
   git clone https://github.com/rgcleanslage/iqq-document-service.git
   cd iqq-document-service && sam build && sam deploy
   ```

2. **Deploy infrastructure last** (repo 1):
   ```bash
   git clone https://github.com/rgcleanslage/iqq-infrastructure.git
   cd iqq-infrastructure && terraform init && terraform apply
   ```

## Technology Stack

### All Repositories
- **Language:** TypeScript
- **Runtime:** Node.js 20.x
- **Architecture:** ARM64 (cost optimized)
- **Testing:** Jest with coverage
- **Logging:** Structured JSON logs
- **Tracing:** AWS X-Ray

### Infrastructure
- **IaC:** Terraform
- **Deployment:** AWS SAM CLI
- **Authentication:** Cognito OAuth 2.0
- **API:** API Gateway REST API
- **Orchestration:** Step Functions

## Quick Start

### Prerequisites
- Node.js 20.x
- AWS CLI configured
- AWS SAM CLI
- Terraform >= 1.5
- Git

### Clone All Repositories

```bash
# Create workspace directory
mkdir iqq-platform && cd iqq-platform

# Clone main documentation repository
git clone https://github.com/rgcleanslage/iqq-project.git

# Clone all service repositories
git clone https://github.com/rgcleanslage/iqq-infrastructure.git
git clone https://github.com/rgcleanslage/iqq-providers.git
git clone https://github.com/rgcleanslage/iqq-lender-service.git
git clone https://github.com/rgcleanslage/iqq-package-service.git
git clone https://github.com/rgcleanslage/iqq-product-service.git
git clone https://github.com/rgcleanslage/iqq-document-service.git
```

### Deploy Everything

```bash
# Deploy Lambda services (15-20 minutes)
for service in iqq-providers iqq-lender-service iqq-package-service iqq-product-service iqq-document-service; do
  cd $service
  npm install
  sam build
  sam deploy
  cd ..
done

# Deploy infrastructure (5 minutes)
cd iqq-infrastructure
terraform init
terraform apply
cd ..
```

### Test Deployment

```bash
cd iqq-infrastructure

# Get API URL and credentials
API_URL=$(terraform output -raw api_gateway_url)
CLIENT_ID=$(terraform output -raw cognito_client_id)
CLIENT_SECRET=$(terraform output -raw cognito_client_secret)
COGNITO_DOMAIN=$(terraform output -raw cognito_domain)

# Get OAuth token
TOKEN=$(curl -s -X POST "https://${COGNITO_DOMAIN}/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Test endpoints
curl -X GET "${API_URL}/lender" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: YOUR_API_KEY"
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     API Gateway (REST)                       │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐  │
│  │ /lender  │ /package │ /product │/document │/authorize│  │
│  └────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┘  │
└───────┼──────────┼──────────┼──────────┼──────────┼────────┘
        │          │          │          │          │
        │          │          │          │          │
   ┌────▼────┐┌───▼────┐┌────▼────┐┌────▼────┐┌───▼────┐
   │ Lender  ││Package ││ Product ││Document ││Authorizer
   │ Service ││Service ││ Service ││ Service ││(OAuth+Key)
   └─────────┘└───┬────┘└─────────┘└─────────┘└─────────┘
                  │
            ┌─────▼─────┐
            │   Step    │
            │ Functions │
            └─────┬─────┘
                  │
        ┌─────────┼─────────┐
        │         │         │
   ┌────▼────┐┌──▼───┐┌────▼────┐
   │Provider ││Provider││Provider │
   │   1     ││   2   ││   3     │
   │ (HTTP)  ││ (HTTP)││ (HTTP)  │
   └────┬────┘└───┬───┘└────┬────┘
        │         │         │
   ┌────▼────┐┌──▼───┐┌────▼────┐
   │Adapter  ││Adapter││  JSON   │
   │  CSV    ││  XML  ││ (direct)│
   └─────────┘└───────┘└─────────┘
```

## Documentation

Each repository contains:
- **README.md** - Setup and deployment instructions
- **API documentation** - Endpoint specifications
- **Architecture diagrams** - Component interactions
- **Testing guide** - How to run tests

## Security

### Secrets Management
- OAuth client secrets in Cognito
- API keys in environment variables
- No secrets in code repositories

### Authentication
- OAuth 2.0 client credentials flow
- JWT token validation
- API key validation (required)

### Authorization
- IAM roles with least privilege
- Path-based access control (optional)
- Request authorizer validation

## Monitoring

### CloudWatch Logs
- Structured JSON logging
- Correlation ID tracking
- 7-day retention

### X-Ray Tracing
- Distributed tracing enabled
- End-to-end request tracking
- Performance analysis

### CloudWatch Metrics
- Lambda invocations, duration, errors
- API Gateway requests, latency
- Step Functions executions

## Cost Optimization

- ARM64 architecture (20% cheaper)
- On-demand DynamoDB
- 7-day log retention
- Right-sized Lambda memory (512MB)
- No provisioned concurrency

## Support

For issues or questions:
1. Check repository README files
2. Review CloudWatch Logs
3. Check X-Ray traces
4. Review deployment documentation

## Contributing

Each repository follows the same structure:
- TypeScript with strict mode
- Jest for testing
- ESLint for linting
- Prettier for formatting

## License

This is a reference architecture for demonstration purposes.

---

**Last Updated:** February 16, 2026  
**Platform Version:** 1.0.0  
**Maintained by:** iQQ Platform Team
