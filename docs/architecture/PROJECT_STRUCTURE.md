# iQQ Platform - Project Structure

## Repository Organization

```
allied2/                                    ← Root workspace
│
├── iqq-providers/                          ← Provider services (consolidated)
│   ├── adapters/
│   │   ├── csv/                           ← Generic CSV to JSON adapter
│   │   └── xml/                           ← Generic XML to JSON adapter
│   ├── providers/
│   │   ├── client/                        ← Client Insurance stub
│   │   ├── route66/                       ← Route 66 Insurance stub
│   │   └── apco/                          ← APCO Insurance stub
│   ├── authorizer/                        ← API Gateway authorizer
│   ├── template.yaml                      ← SAM template (all functions)
│   ├── samconfig.toml                     ← Deployment config
│   ├── package.json                       ← Root with workspaces
│   └── README.md
│
├── iqq-infrastructure/                     ← Terraform infrastructure
│   ├── modules/
│   │   ├── api-gateway/                   ← API Gateway module
│   │   ├── cognito/                       ← Cognito user pool
│   │   ├── dynamodb/                      ← DynamoDB tables
│   │   ├── lambda-versioning/             ← Lambda versioning
│   │   └── step-functions/                ← Step Functions orchestration
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── iqq-document-service/                   ← Document microservice
│   ├── src/
│   ├── template.yaml
│   └── package.json
│
├── iqq-lender-service/                     ← Lender microservice
│   ├── src/
│   ├── template.yaml
│   └── package.json
│
├── iqq-product-service/                    ← Product microservice
│   ├── src/
│   ├── template.yaml
│   └── package.json
│
├── iqq-package-service/                    ← Package microservice
│   ├── src/
│   ├── template.yaml
│   └── package.json
│
├── scripts/                                ← Utility scripts
│   ├── seed-dynamodb.ts                   ← Seed DynamoDB with test data
│   └── package.json
│
├── openapi.yaml                           ← API specification
├── openapi-soapui.yaml                    ← SoapUI-compatible spec
├── iQQ-API-SoapUI-Project.xml            ← SoapUI test project
│
└── Documentation/
    ├── ADAPTER_ARCHITECTURE.md            ← Adapter design
    ├── API_KEY_DEPLOYMENT_GUIDE.md        ← API key setup
    ├── DEPLOYMENT_GUIDE.md                ← Deployment instructions
    ├── OPENAPI_GUIDE.md                   ← OpenAPI usage
    ├── PATH_BASED_ACCESS_CONTROL_GUIDE.md ← Access control
    ├── REPOSITORY_CONSOLIDATION.md        ← Repo structure changes
    ├── SOAPUI_TESTING_GUIDE.md           ← SoapUI testing
    └── PROJECT_STRUCTURE.md               ← This file
```

## Component Overview

### 1. iqq-providers/ (Consolidated)
**Purpose**: All provider-related Lambda functions  
**Stack**: `iqq-providers`  
**Functions**: 7 total
- 2 Adapters (CSV, XML)
- 3 Providers (Client, Route 66, APCO)
- 1 Authorizer

**Deployment**:
```bash
cd iqq-providers
npm install
npm run build
sam deploy
```

### 2. iqq-infrastructure/ (Terraform)
**Purpose**: All AWS infrastructure as code  
**Modules**: 5 total
- API Gateway
- Cognito
- DynamoDB
- Lambda Versioning
- Step Functions

**Deployment**:
```bash
cd iqq-infrastructure
terraform init
terraform plan
terraform apply
```

### 3. Core Microservices (4 services)
**Purpose**: Business logic microservices  
**Services**:
- Document Service
- Lender Service
- Product Service
- Package Service

**Deployment** (each service):
```bash
cd iqq-{service}-service
npm install
npm run build
sam deploy
```

### 4. Scripts & Utilities
**Purpose**: Development and deployment utilities  
**Scripts**:
- `seed-dynamodb.ts` - Populate DynamoDB with test data
- `get-api-keys.sh` - Retrieve API keys from Terraform
- `get-oauth-token.sh` - Get OAuth token for testing

### 5. API Documentation
**Purpose**: API specifications and testing  
**Files**:
- `openapi.yaml` - Full OpenAPI 3.0 specification
- `openapi-soapui.yaml` - SoapUI-compatible version
- `iQQ-API-SoapUI-Project.xml` - SoapUI test project

## Deployment Order

1. **Infrastructure** (Terraform)
   ```bash
   cd iqq-infrastructure
   terraform apply
   ```

2. **Providers** (SAM)
   ```bash
   cd iqq-providers
   sam deploy
   ```

3. **Core Services** (SAM - each service)
   ```bash
   cd iqq-document-service && sam deploy
   cd iqq-lender-service && sam deploy
   cd iqq-product-service && sam deploy
   cd iqq-package-service && sam deploy
   ```

4. **Seed Data** (Optional)
   ```bash
   cd scripts
   npm install
   ts-node seed-dynamodb.ts
   ```

## Technology Stack

### Backend
- **Runtime**: Node.js 20 (ARM64)
- **Language**: TypeScript
- **Framework**: AWS SAM
- **Infrastructure**: Terraform

### AWS Services
- **Compute**: Lambda
- **API**: API Gateway (REST)
- **Auth**: Cognito + Custom Authorizer
- **Database**: DynamoDB
- **Orchestration**: Step Functions
- **Monitoring**: CloudWatch

### Development Tools
- **Package Manager**: npm (workspaces)
- **Build Tool**: TypeScript Compiler
- **Testing**: SoapUI, Jest
- **API Spec**: OpenAPI 3.0

## Environment Variables

### All Lambda Functions
- `ENVIRONMENT`: dev/staging/prod
- `TABLE_NAME`: DynamoDB table name
- `LOG_LEVEL`: INFO/DEBUG/ERROR

### Authorizer
- `COGNITO_USER_POOL_ID`: Cognito user pool
- `COGNITO_CLIENT_ID`: Cognito client ID

## CloudFormation Stacks

| Stack Name | Components | Status |
|------------|------------|--------|
| `iqq-providers` | 7 Lambda functions | ✅ Active |
| `iqq-document-service-dev` | Document service | ✅ Active |
| `iqq-lender-service-dev` | Lender service | ✅ Active |
| `iqq-product-service-dev` | Product service | ✅ Active |
| `iqq-package-service-dev` | Package service | ✅ Active |

## DynamoDB Tables

| Table Name | Purpose | Keys |
|------------|---------|------|
| `iqq-config-dev` | Configuration | PK, SK |
| `iqq-documents-dev` | Documents | documentId |
| `iqq-lenders-dev` | Lenders | lenderId |
| `iqq-products-dev` | Products | productId |

## API Endpoints

### Base URL
```
https://{api-id}.execute-api.us-east-1.amazonaws.com/dev
```

### Endpoints
- `GET /documents` - List documents
- `POST /documents` - Create document
- `GET /lenders` - List lenders
- `POST /lenders` - Create lender
- `GET /products` - List products
- `POST /products` - Create product
- `GET /packages/quote` - Get package quotes
- `POST /packages/accept` - Accept package quote

## Development Workflow

### 1. Make Changes
```bash
# Edit code in appropriate service
vim iqq-providers/adapters/csv/src/index.ts
```

### 2. Build
```bash
cd iqq-providers
npm run build
```

### 3. Test Locally
```bash
sam local invoke CSVAdapterFunction -e test-event.json
```

### 4. Deploy
```bash
sam deploy
```

### 5. Test in AWS
```bash
aws lambda invoke \
  --function-name iqq-adapter-csv-dev \
  --payload file://test-event.json \
  response.json
```

## Monitoring

### CloudWatch Log Groups
- `/aws/lambda/iqq-adapter-csv-dev`
- `/aws/lambda/iqq-adapter-xml-dev`
- `/aws/lambda/iqq-provider-client-dev`
- `/aws/lambda/iqq-provider-route66-dev`
- `/aws/lambda/iqq-provider-apco-dev`
- `/aws/lambda/iqq-authorizer-dev`
- `/aws/lambda/iqq-document-service-dev`
- `/aws/lambda/iqq-lender-service-dev`
- `/aws/lambda/iqq-product-service-dev`
- `/aws/lambda/iqq-package-service-dev`

### Metrics
- Lambda invocations
- Lambda errors
- Lambda duration
- API Gateway requests
- DynamoDB read/write capacity

## Cost Optimization

- ARM64 architecture (20% cheaper)
- Right-sized memory (512MB for most functions)
- 7-day log retention
- On-demand DynamoDB billing
- API Gateway caching enabled

## Security

- OAuth 2.0 authentication via Cognito
- API Key validation
- IAM roles with least privilege
- Encryption at rest (DynamoDB)
- Encryption in transit (HTTPS)
- VPC endpoints (optional)

## Future Enhancements

- [ ] Consolidate 4 microservices into `iqq-services/`
- [ ] Add CI/CD pipeline
- [ ] Add automated testing
- [ ] Add API rate limiting
- [ ] Add request/response caching
- [ ] Add distributed tracing (X-Ray)

---

**Last Updated**: February 16, 2026  
**Maintained By**: iQQ Platform Team
