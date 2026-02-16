# iQQ Insurance Quoting Platform - System Architecture

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                    CLIENT LAYER                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  Web/Mobile Apps  │  Partner Systems  │  Third-Party Integrations                   │
└──────────────────────────────┬──────────────────────────────────────────────────────┘
                               │
                               │ HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              API GATEWAY LAYER                                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  Amazon API Gateway (REST API)                                              │   │
│  │  • Custom Domain: iqq-api-dev.execute-api.us-east-1.amazonaws.com          │   │
│  │  • Endpoints: /lender, /product, /package, /document                        │   │
│  │  • Rate Limiting & Throttling                                               │   │
│  │  • Request/Response Transformation                                          │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                               │
│                                      ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  Custom Lambda Authorizer                                                   │   │
│  │  • OAuth 2.0 Token Validation (Cognito)                                     │   │
│  │  • API Key Validation                                                       │   │
│  │  • Dual Authentication Support                                              │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────┬──────────────────────────────────────────────────────┘
                               │
                               │ Authorized Requests
                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           AUTHENTICATION LAYER                                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────┐        ┌──────────────────────────────────────────┐  │
│  │  Amazon Cognito          │        │  API Gateway Usage Plans                 │  │
│  │  • User Pool             │        │  • Standard Plan (default key)           │  │
│  │  • OAuth 2.0 Flows       │        │  • Premium Plan (Partner A)              │  │
│  │  • JWT Token Generation  │        │  • Standard Plan (Partner B)             │  │
│  │  • Scopes: read, write   │        │  • Rate Limits & Quotas                  │  │
│  └──────────────────────────┘        └──────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────────────────────┘
                               │
                               │ Invoke Lambda Functions
                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          MICROSERVICES LAYER                                         │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Lender     │  │   Product    │  │   Package    │  │  Document    │          │
│  │   Service    │  │   Service    │  │   Service    │  │   Service    │          │
│  │              │  │              │  │              │  │              │          │
│  │  Lambda      │  │  Lambda      │  │  Lambda      │  │  Lambda      │          │
│  │  Node.js 20  │  │  Node.js 20  │  │  Node.js 20  │  │  Node.js 20  │          │
│  │  TypeScript  │  │  TypeScript  │  │  TypeScript  │  │  TypeScript  │          │
│  └──────────────┘  └──────────────┘  └──────┬───────┘  └──────────────┘          │
│                                              │                                      │
│                                              │ Invokes Step Functions               │
│                                              ▼                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        ORCHESTRATION LAYER                                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  AWS Step Functions (EXPRESS State Machine)                                 │   │
│  │  • Dynamic Provider Orchestration                                           │   │
│  │  • Synchronous Execution (StartSyncExecutionCommand)                        │   │
│  │  • Parallel Processing with Map State                                       │   │
│  │  • Error Handling & Retry Logic                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  Flow:                                                                               │
│  1. LoadActiveProviders → Query DynamoDB for active providers                       │
│  2. CheckProvidersFound → Validate provider count                                   │
│  3. ProcessProvidersMap → Map state (parallel, max 10 concurrent)                   │
│     ├─ InvokeProvider → Call provider Lambda                                        │
│     ├─ CheckAdapterNeeded → Check if adapter required (adapterArn != null)          │
│     ├─ InvokeAdapter → Transform response (CSV/XML → JSON)                          │
│     └─ FormatResponse → Standardize output                                          │
│  4. AggregateQuotes → Collect all successful quotes                                 │
│  5. FormatFinalResponse → Return aggregated results                                 │
└──────────────────────────────┬──────────────────────────────────────────────────────┘
                               │
                               │ Queries & Invokes
                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          PROVIDER INTEGRATION LAYER                                  │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │  Provider Loader Lambda                                                      │  │
│  │  • Queries DynamoDB GSI2 (STATUS#ACTIVE)                                     │  │
│  │  • Returns: providerId, providerName, lambdaArn, adapterArn, rating         │  │
│  │  • Dynamic provider discovery                                                │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐        │
│  │  Client Insurance   │  │  Route 66 Insurance │  │  APCO Insurance     │        │
│  │  Provider Lambda    │  │  Provider Lambda    │  │  Provider Lambda    │        │
│  │                     │  │                     │  │                     │        │
│  │  Returns: CSV       │  │  Returns: JSON      │  │  Returns: XML       │        │
│  │  $1,249.99          │  │  $1,149.99 ⭐       │  │  $1,287.49          │        │
│  └──────────┬──────────┘  └──────────┬──────────┘  └──────────┬──────────┘        │
│             │                        │                        │                    │
│             ▼                        │                        ▼                    │
│  ┌─────────────────────┐             │             ┌─────────────────────┐        │
│  │  CSV Adapter        │             │             │  XML Adapter        │        │
│  │  Lambda             │             │             │  Lambda             │        │
│  │                     │             │             │                     │        │
│  │  CSV → JSON         │             │             │  XML → JSON         │        │
│  │  Config-driven      │             │             │  Config-driven      │        │
│  │  DynamoDB mappings  │             │             │  DynamoDB mappings  │        │
│  └─────────────────────┘             │             └─────────────────────┘        │
│                                      │                                             │
│                                      │ (No adapter needed)                         │
│                                      ▼                                             │
└─────────────────────────────────────────────────────────────────────────────────────┘
                               │
                               │ Read/Write Configuration
                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            DATA LAYER                                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  Amazon DynamoDB (iqq-config-dev)                                           │   │
│  │  • Single-Table Design                                                      │   │
│  │  • Partition Key: PK, Sort Key: SK                                          │   │
│  │  • GSI1: Entity Type Index (GSI1PK, GSI1SK)                                 │   │
│  │  • GSI2: Status Index (GSI2PK, GSI2SK)                                      │   │
│  │                                                                              │   │
│  │  Data Entities:                                                             │   │
│  │  ├─ Clients (2 records)                                                     │   │
│  │  ├─ Products (3 records: MBP, GAP, VDP)                                     │   │
│  │  ├─ Providers (3 records: Client, Route66, APCO)                            │   │
│  │  │   • providerId, providerName, lambdaArn, adapterArn                      │   │
│  │  │   • responseFormat, rating, status                                       │   │
│  │  └─ Mappings (3 records: field transformations)                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          INFRASTRUCTURE LAYER                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────┐        ┌──────────────────────────────────────────┐  │
│  │  Terraform (IaC)         │        │  AWS SAM (Serverless)                    │  │
│  │  • API Gateway           │        │  • Lambda Functions                      │  │
│  │  • Cognito               │        │  • Build & Deploy                        │  │
│  │  • DynamoDB              │        │  • Local Testing                         │  │
│  │  • Step Functions        │        │  • CloudFormation Stacks                 │  │
│  │  • Lambda Versioning     │        │  • Environment Variables                 │  │
│  │  • CloudWatch            │        │  • IAM Roles & Policies                  │  │
│  └──────────────────────────┘        └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          MONITORING & LOGGING                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────┐        ┌──────────────────────────────────────────┐  │
│  │  CloudWatch Logs         │        │  CloudWatch Metrics & Alarms             │  │
│  │  • Lambda Logs (7 days)  │        │  • API Gateway Metrics                   │  │
│  │  • API Gateway Logs      │        │  • Lambda Invocations                    │  │
│  │  • Step Functions Logs   │        │  • Step Functions Failures               │  │
│  │  • Structured Logging    │        │  • DynamoDB Throttling                   │  │
│  └──────────────────────────┘        └──────────────────────────────────────────┘  │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  AWS X-Ray                                                                   │   │
│  │  • Distributed Tracing                                                       │   │
│  │  • Service Map Visualization                                                 │   │
│  │  • Performance Analysis                                                      │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Request Flow: Package Endpoint

```
1. Client Request
   │
   ├─→ GET /package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000
   │   Headers: Authorization: Bearer <token>, x-api-key: <key>
   │
   ▼
2. API Gateway
   │
   ├─→ Custom Authorizer Lambda
   │   ├─ Validate OAuth token (Cognito)
   │   ├─ Validate API key
   │   └─ Generate IAM policy
   │
   ▼
3. Package Service Lambda
   │
   ├─→ Invoke Step Functions (StartSyncExecutionCommand)
   │   └─ Wait for synchronous response
   │
   ▼
4. Step Functions State Machine
   │
   ├─→ LoadActiveProviders
   │   └─ Provider Loader Lambda → Query DynamoDB
   │       Returns: [Client, Route66, APCO] with Lambda ARNs
   │
   ├─→ ProcessProvidersMap (Parallel - Map State)
   │   │
   │   ├─→ Branch 1: Client Insurance
   │   │   ├─ InvokeProvider → Client Lambda → Returns CSV
   │   │   ├─ CheckAdapterNeeded → adapterArn present
   │   │   ├─ InvokeAdapter → CSV Adapter → Returns JSON
   │   │   └─ FormatAdapterResponse → Standardized quote
   │   │
   │   ├─→ Branch 2: Route 66 Insurance
   │   │   ├─ InvokeProvider → Route66 Lambda → Returns JSON
   │   │   ├─ CheckAdapterNeeded → adapterArn is null
   │   │   └─ FormatJSONResponse → Standardized quote
   │   │
   │   └─→ Branch 3: APCO Insurance
   │       ├─ InvokeProvider → APCO Lambda → Returns XML
   │       ├─ CheckAdapterNeeded → adapterArn present
   │       ├─ InvokeAdapter → XML Adapter → Returns JSON
   │       └─ FormatAdapterResponse → Standardized quote
   │
   ├─→ AggregateQuotes
   │   └─ Filter successful quotes (statusCode == 200)
   │
   └─→ FormatFinalResponse
       └─ Return: { quotes: [...], quotesFound: 3, errors: [] }
   │
   ▼
5. Package Service Lambda
   │
   ├─→ Parse Step Functions output
   ├─→ Calculate pricing (best quote + 5% discount)
   ├─→ Build package response
   │   ├─ providerQuotes: [Client, Route66, APCO]
   │   ├─ pricing: { basePrice, totalPrice, averagePremium }
   │   ├─ bestQuote: Route66 ($1,149.99)
   │   └─ summary: { totalQuotes: 3, successfulQuotes: 3 }
   │
   ▼
6. API Gateway
   │
   └─→ Return 200 OK with aggregated package data
   │
   ▼
7. Client receives response (~2 seconds total)
```

## Technology Stack

### Frontend/Client
- **Protocol**: HTTPS/REST
- **Authentication**: OAuth 2.0 Bearer Tokens + API Keys
- **Format**: JSON

### API Layer
- **API Gateway**: AWS API Gateway (REST API)
- **Authentication**: 
  - Amazon Cognito (OAuth 2.0, JWT)
  - API Keys with Usage Plans
- **Authorizer**: Custom Lambda Authorizer (Node.js 20)

### Compute Layer
- **Runtime**: AWS Lambda (Node.js 20, ARM64)
- **Language**: TypeScript
- **Framework**: AWS SAM (Serverless Application Model)
- **Functions**:
  - 4 Microservices (Lender, Product, Package, Document)
  - 1 Provider Loader
  - 3 Provider Integrations (Client, Route66, APCO)
  - 2 Generic Adapters (CSV, XML)
  - 1 Custom Authorizer

### Orchestration Layer
- **Service**: AWS Step Functions (EXPRESS State Machine)
- **Pattern**: Map State for parallel processing
- **Execution**: Synchronous (StartSyncExecutionCommand)
- **Max Concurrency**: 10 providers
- **Features**:
  - Dynamic provider loading
  - Conditional adapter invocation
  - Error handling & retries
  - JSONPath filtering

### Data Layer
- **Database**: Amazon DynamoDB
- **Design**: Single-table design
- **Indexes**:
  - Primary: PK (Partition), SK (Sort)
  - GSI1: Entity type queries
  - GSI2: Status-based queries
- **Capacity**: On-demand

### Infrastructure as Code
- **Terraform**: Infrastructure provisioning
  - API Gateway, Cognito, DynamoDB
  - Step Functions, Lambda versioning
  - CloudWatch, IAM
- **AWS SAM**: Lambda deployment
  - Build, package, deploy
  - Environment configuration
  - IAM roles & policies

### Monitoring & Observability
- **CloudWatch Logs**: 7-day retention
- **CloudWatch Metrics**: Custom metrics & alarms
- **AWS X-Ray**: Distributed tracing
- **Structured Logging**: JSON format with correlation IDs

### Development Tools
- **Language**: TypeScript 5.3
- **Package Manager**: npm
- **Testing**: Jest
- **Linting**: ESLint
- **Build**: TypeScript Compiler (tsc)

## Key Architectural Patterns

### 1. Microservices Architecture
- Independent, single-purpose services
- Loose coupling via API Gateway
- Individual deployment & scaling

### 2. Adapter Pattern
- Generic CSV and XML adapters
- Configuration-driven transformations
- Reusable across providers

### 3. Single-Table Design (DynamoDB)
- All entities in one table
- Access patterns via GSIs
- Efficient queries with composite keys

### 4. Dynamic Orchestration
- Provider configuration in DynamoDB
- No code changes for new providers
- Runtime provider discovery

### 5. Dual Authentication
- OAuth 2.0 for user authentication
- API Keys for partner/system access
- Custom authorizer for validation

### 6. Synchronous Step Functions
- EXPRESS state machine type
- Immediate response to API calls
- Suitable for real-time quotes

### 7. Infrastructure as Code
- Terraform for AWS resources
- SAM for Lambda functions
- Version controlled & repeatable

## Scalability & Performance

- **API Gateway**: Handles millions of requests
- **Lambda**: Auto-scales per request
- **Step Functions**: 10 concurrent providers (configurable)
- **DynamoDB**: On-demand capacity, auto-scaling
- **Response Time**: ~2 seconds for 3 providers

## Security Features

- **Authentication**: OAuth 2.0 + API Keys
- **Authorization**: IAM policies via custom authorizer
- **Encryption**: TLS 1.2+ in transit, at rest
- **Secrets**: AWS Secrets Manager (Cognito client secret)
- **Least Privilege**: IAM roles with minimal permissions
- **API Protection**: Rate limiting, throttling, usage plans

## Deployment Architecture

```
Development → Build → Test → Deploy

Terraform:
  terraform plan → terraform apply
  
SAM:
  npm run build → sam build → sam deploy
  
DynamoDB:
  npx ts-node seed-dynamodb.ts
```

## Cost Optimization

- **Lambda**: Pay per invocation (ARM64 for cost savings)
- **DynamoDB**: On-demand pricing (no idle costs)
- **Step Functions**: EXPRESS type (cheaper than STANDARD)
- **API Gateway**: REST API (lower cost than HTTP API for this use case)
- **CloudWatch**: 7-day log retention (reduced storage costs)
