# iQQ Insurance Quoting Platform - Visual Architecture

## System Architecture Overview

```mermaid
graph TB
    subgraph "Client Layer"
        Client[Web/Mobile Apps<br/>Partner Systems]
    end
    
    subgraph "AWS Cloud"
        subgraph "API Gateway Layer"
            APIGW[API Gateway<br/>REST API<br/>r8ukhidr1m]
            Auth[Custom Authorizer<br/>Lambda]
            
            APIGW --> Auth
        end
        
        subgraph "Authentication"
            Cognito[Amazon Cognito<br/>OAuth 2.0 + JWT]
            APIKeys[API Keys<br/>Usage Plans]
            
            Auth --> Cognito
            Auth --> APIKeys
        end
        
        subgraph "Microservices Layer"
            Lender[Lender Service<br/>Lambda<br/>Node.js 20]
            Product[Product Service<br/>Lambda<br/>Node.js 20]
            Package[Package Service<br/>Lambda<br/>Node.js 20]
            Document[Document Service<br/>Lambda<br/>Node.js 20]
        end
        
        subgraph "Orchestration Layer"
            SF[Step Functions<br/>EXPRESS State Machine<br/>Dynamic Provider Orchestration]
            
            subgraph "Step Functions Flow"
                SF1[1. Load Active Providers]
                SF2[2. Check Providers Found]
                SF3[3. Process Providers Map<br/>Parallel Execution]
                SF4[4. Aggregate Quotes]
                SF5[5. Format Response]
                
                SF1 --> SF2
                SF2 --> SF3
                SF3 --> SF4
                SF4 --> SF5
            end
        end
        
        subgraph "Provider Integration Layer"
            PL[Provider Loader<br/>Lambda]
            
            subgraph "Providers"
                P1[Client Insurance<br/>Lambda<br/>Returns CSV]
                P2[Route 66 Insurance<br/>Lambda<br/>Returns JSON]
                P3[APCO Insurance<br/>Lambda<br/>Returns XML]
            end
            
            subgraph "Adapters"
                A1[CSV Adapter<br/>Lambda<br/>CSV → JSON]
                A2[XML Adapter<br/>Lambda<br/>XML → JSON]
            end
            
            P1 --> A1
            P3 --> A2
        end
        
        subgraph "Data Layer"
            DDB[(DynamoDB<br/>iqq-config-dev<br/>Single Table Design)]
            
            subgraph "DynamoDB Entities"
                E1[Clients: 2]
                E2[Products: 3]
                E3[Providers: 3]
                E4[Mappings: 3]
            end
        end
        
        subgraph "Monitoring"
            CW[CloudWatch<br/>Logs & Metrics]
            XRay[AWS X-Ray<br/>Tracing]
        end
    end
    
    Client -->|HTTPS<br/>OAuth + API Key| APIGW
    APIGW --> Lender
    APIGW --> Product
    APIGW --> Package
    APIGW --> Document
    
    Package -->|StartSyncExecution| SF
    SF --> SF1
    SF1 --> PL
    PL -->|Query GSI2| DDB
    
    SF3 -->|Parallel| P1
    SF3 -->|Parallel| P2
    SF3 -->|Parallel| P3
    
    A1 -->|Read Mappings| DDB
    A2 -->|Read Mappings| DDB
    
    Lender -.->|Logs| CW
    Product -.->|Logs| CW
    Package -.->|Logs| CW
    Document -.->|Logs| CW
    SF -.->|Logs| CW
    
    Package -.->|Trace| XRay
    SF -.->|Trace| XRay
    
    style Client fill:#e1f5ff
    style APIGW fill:#ff9900
    style Auth fill:#ff9900
    style Cognito fill:#dd344c
    style SF fill:#cc2264
    style DDB fill:#527fff
    style Package fill:#ff9900
    style CW fill:#ff4f8b
    style XRay fill:#ff4f8b
```

## Package Endpoint Request Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant AG as API Gateway
    participant A as Authorizer
    participant PS as Package Service
    participant SF as Step Functions
    participant PL as Provider Loader
    participant DB as DynamoDB
    participant P1 as Client Provider
    participant P2 as Route66 Provider
    participant P3 as APCO Provider
    participant AD1 as CSV Adapter
    participant AD2 as XML Adapter
    
    C->>AG: GET /package?productCode=MBP
    Note over C,AG: Headers: OAuth Token + API Key
    
    AG->>A: Authorize Request
    A->>A: Validate OAuth Token
    A->>A: Validate API Key
    A-->>AG: IAM Policy (Allow)
    
    AG->>PS: Invoke Lambda
    
    PS->>SF: StartSyncExecution
    Note over PS,SF: Synchronous invocation
    
    SF->>PL: Load Active Providers
    PL->>DB: Query GSI2 (STATUS#ACTIVE)
    DB-->>PL: [Client, Route66, APCO]
    PL-->>SF: Provider List with ARNs
    
    Note over SF: Map State - Parallel Processing
    
    par Provider 1: Client Insurance
        SF->>P1: Invoke (productCode, coverage, etc)
        P1-->>SF: CSV Response
        SF->>AD1: Transform CSV
        AD1->>DB: Read Mappings
        DB-->>AD1: Field Mappings
        AD1-->>SF: JSON Quote ($1,249.99)
    and Provider 2: Route 66
        SF->>P2: Invoke (productCode, coverage, etc)
        P2-->>SF: JSON Response ($1,149.99)
        Note over SF,P2: No adapter needed
    and Provider 3: APCO
        SF->>P3: Invoke (productCode, coverage, etc)
        P3-->>SF: XML Response
        SF->>AD2: Transform XML
        AD2->>DB: Read Mappings
        DB-->>AD2: Field Mappings
        AD2-->>SF: JSON Quote ($1,287.49)
    end
    
    SF->>SF: Aggregate Quotes
    SF->>SF: Format Response
    SF-->>PS: {quotes: 3, errors: 0}
    
    PS->>PS: Calculate Pricing
    PS->>PS: Select Best Quote (Route66)
    PS->>PS: Apply 5% Discount
    
    PS-->>AG: Package Response
    AG-->>C: 200 OK + JSON
    
    Note over C: Total Time: ~2 seconds
    Note over C: Best Quote: $1,092.49
```

## Step Functions State Machine Flow

```mermaid
stateDiagram-v2
    [*] --> LoadActiveProviders
    
    LoadActiveProviders --> CheckProvidersFound
    note right of LoadActiveProviders
        Query DynamoDB for
        active providers
        Returns: Array of providers
        with Lambda ARNs
    end note
    
    CheckProvidersFound --> ProcessProvidersMap: Count > 0
    CheckProvidersFound --> NoProvidersFound: Count = 0
    
    NoProvidersFound --> [*]
    
    state ProcessProvidersMap {
        [*] --> InvokeProvider
        
        InvokeProvider --> CheckAdapterNeeded
        note right of InvokeProvider
            Dynamic Lambda invocation
            using lambdaArn from DynamoDB
        end note
        
        CheckAdapterNeeded --> InvokeAdapter: adapterArn != null
        CheckAdapterNeeded --> FormatJSONResponse: adapterArn = null
        
        InvokeAdapter --> FormatAdapterResponse
        note right of InvokeAdapter
            CSV Adapter or XML Adapter
            Config-driven transformation
        end note
        
        FormatAdapterResponse --> [*]
        FormatJSONResponse --> [*]
        
        state "Error Handling" as EH {
            InvokeProvider --> ProviderError: Error
            InvokeAdapter --> AdapterError: Error
        }
        
        ProviderError --> [*]
        AdapterError --> [*]
    }
    
    ProcessProvidersMap --> AggregateQuotes
    note right of ProcessProvidersMap
        Map State
        Max Concurrency: 10
        Processes N providers
        in parallel
    end note
    
    AggregateQuotes --> FormatFinalResponse
    note right of AggregateQuotes
        Filter successful quotes
        (statusCode = 200)
        Collect errors
    end note
    
    FormatFinalResponse --> [*]
```

## Data Model - DynamoDB Single Table Design

```mermaid
erDiagram
    CONFIG_TABLE {
        string PK "Partition Key"
        string SK "Sort Key"
        string GSI1PK "Entity Type Index PK"
        string GSI1SK "Entity Type Index SK"
        string GSI2PK "Status Index PK"
        string GSI2SK "Status Index SK"
    }
    
    CLIENT {
        string clientId
        string clientName
        string status
        json contactInfo
        string createdAt
    }
    
    PRODUCT {
        string productId
        string productName
        string productType
        string description
        number basePremium
        string status
    }
    
    PROVIDER {
        string providerId
        string providerName
        string lambdaArn
        string responseFormat
        string adapterArn
        string rating
        string status
        number timeout
    }
    
    MAPPING {
        string productId
        string providerId
        number version
        boolean active
        json mappingConfig
    }
    
    CONFIG_TABLE ||--o{ CLIENT : contains
    CONFIG_TABLE ||--o{ PRODUCT : contains
    CONFIG_TABLE ||--o{ PROVIDER : contains
    CONFIG_TABLE ||--o{ MAPPING : contains
    
    PROVIDER ||--o{ MAPPING : "has mappings"
    PRODUCT ||--o{ MAPPING : "has mappings"
```

## Provider Integration Pattern

```mermaid
graph LR
    subgraph "Step Functions"
        SF[Map State<br/>Iterate Providers]
    end
    
    subgraph "Provider 1: Client Insurance"
        P1[Provider Lambda<br/>Returns CSV]
        A1[CSV Adapter<br/>Transform to JSON]
        P1 --> A1
    end
    
    subgraph "Provider 2: Route 66"
        P2[Provider Lambda<br/>Returns JSON]
    end
    
    subgraph "Provider 3: APCO"
        P3[Provider Lambda<br/>Returns XML]
        A2[XML Adapter<br/>Transform to JSON]
        P3 --> A2
    end
    
    subgraph "Configuration"
        DB[(DynamoDB)]
    end
    
    SF -->|Invoke| P1
    SF -->|Invoke| P2
    SF -->|Invoke| P3
    
    A1 -->|Read Mappings| DB
    A2 -->|Read Mappings| DB
    
    A1 -->|Standardized Quote| SF
    P2 -->|Standardized Quote| SF
    A2 -->|Standardized Quote| SF
    
    style P1 fill:#4CAF50
    style P2 fill:#2196F3
    style P3 fill:#FF9800
    style A1 fill:#9C27B0
    style A2 fill:#9C27B0
    style DB fill:#527fff
    style SF fill:#cc2264
```

## Authentication Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant AG as API Gateway
    participant Auth as Custom Authorizer
    participant Cog as Cognito
    participant API as Microservice
    
    Note over C: User Login
    C->>Cog: Authenticate (username/password)
    Cog-->>C: Access Token (JWT)
    
    Note over C: API Request
    C->>AG: Request + Bearer Token + API Key
    
    AG->>Auth: Invoke Authorizer
    
    par OAuth Validation
        Auth->>Cog: Validate JWT Token
        Cog-->>Auth: Token Valid + Claims
    and API Key Validation
        Auth->>Auth: Validate API Key
        Auth->>Auth: Check Usage Plan
    end
    
    Auth->>Auth: Generate IAM Policy
    Auth-->>AG: Allow/Deny Policy
    
    alt Policy = Allow
        AG->>API: Invoke Lambda
        API-->>AG: Response
        AG-->>C: 200 OK
    else Policy = Deny
        AG-->>C: 403 Forbidden
    end
```

## Deployment Architecture

```mermaid
graph TB
    subgraph "Source Control"
        GIT[Git Repository]
    end
    
    subgraph "Infrastructure as Code"
        TF[Terraform<br/>Infrastructure]
        SAM[AWS SAM<br/>Lambda Functions]
        SEED[Seed Script<br/>DynamoDB Data]
    end
    
    subgraph "AWS Resources"
        subgraph "Terraform Managed"
            APIGW[API Gateway]
            COG[Cognito]
            DDB[(DynamoDB)]
            SF[Step Functions]
            CW[CloudWatch]
        end
        
        subgraph "SAM Managed"
            L1[Microservices<br/>4 Lambdas]
            L2[Provider Loader<br/>1 Lambda]
            L3[Providers<br/>3 Lambdas]
            L4[Adapters<br/>2 Lambdas]
            L5[Authorizer<br/>1 Lambda]
        end
    end
    
    GIT --> TF
    GIT --> SAM
    GIT --> SEED
    
    TF -->|terraform apply| APIGW
    TF -->|terraform apply| COG
    TF -->|terraform apply| DDB
    TF -->|terraform apply| SF
    TF -->|terraform apply| CW
    
    SAM -->|sam deploy| L1
    SAM -->|sam deploy| L2
    SAM -->|sam deploy| L3
    SAM -->|sam deploy| L4
    SAM -->|sam deploy| L5
    
    SEED -->|npx ts-node| DDB
    
    style TF fill:#7B42BC
    style SAM fill:#FF9900
    style DDB fill:#527fff
    style SF fill:#cc2264
```

## Technology Stack

```mermaid
mindmap
  root((iQQ Platform))
    Frontend
      HTTPS/REST
      OAuth 2.0
      API Keys
      JSON
    API Layer
      API Gateway
      Custom Authorizer
      Cognito
      Usage Plans
    Compute
      Lambda Node.js 20
      TypeScript
      ARM64
      11 Functions
    Orchestration
      Step Functions
      EXPRESS Type
      Map State
      Parallel Processing
    Data
      DynamoDB
      Single Table
      GSI Indexes
      On-Demand
    Infrastructure
      Terraform
      AWS SAM
      CloudFormation
      Git
    Monitoring
      CloudWatch Logs
      CloudWatch Metrics
      X-Ray Tracing
      Alarms
```

## Cost & Performance Metrics

```mermaid
graph LR
    subgraph "Performance"
        P1[Response Time<br/>~2 seconds]
        P2[Concurrent Providers<br/>Max 10]
        P3[Success Rate<br/>100%]
    end
    
    subgraph "Scalability"
        S1[API Gateway<br/>Millions of requests]
        S2[Lambda<br/>Auto-scales]
        S3[DynamoDB<br/>On-demand capacity]
    end
    
    subgraph "Cost Optimization"
        C1[Lambda ARM64<br/>20% cheaper]
        C2[EXPRESS Step Functions<br/>Lower cost]
        C3[7-day log retention<br/>Reduced storage]
        C4[On-demand DynamoDB<br/>No idle costs]
    end
    
    style P1 fill:#4CAF50
    style P2 fill:#4CAF50
    style P3 fill:#4CAF50
    style S1 fill:#2196F3
    style S2 fill:#2196F3
    style S3 fill:#2196F3
    style C1 fill:#FF9800
    style C2 fill:#FF9800
    style C3 fill:#FF9800
    style C4 fill:#FF9800
```

---

## How to View These Diagrams

These diagrams use **Mermaid** syntax and will render automatically in:
- ✅ GitHub
- ✅ GitLab
- ✅ VS Code (with Mermaid extension)
- ✅ Markdown Preview Enhanced
- ✅ Many documentation platforms

For the best viewing experience, open this file in GitHub or use a Mermaid-compatible Markdown viewer.

## Diagram Legend

- **Orange boxes** (#ff9900): AWS Lambda functions
- **Red boxes** (#dd344c): Amazon Cognito
- **Purple boxes** (#cc2264): AWS Step Functions
- **Blue boxes** (#527fff): Amazon DynamoDB
- **Pink boxes** (#ff4f8b): Monitoring services
- **Green boxes** (#4CAF50): Successful operations
- **Blue boxes** (#2196F3): Scalability features
- **Orange boxes** (#FF9800): Cost optimization
