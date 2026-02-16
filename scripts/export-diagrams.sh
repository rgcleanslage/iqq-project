#!/bin/bash

# Export Mermaid diagrams to PNG images
# Requires: npm install -g @mermaid-js/mermaid-cli

echo "Installing Mermaid CLI if not present..."
npm list -g @mermaid-js/mermaid-cli || npm install -g @mermaid-js/mermaid-cli

echo "Creating output directory..."
mkdir -p docs/architecture/images

echo "Extracting and exporting diagrams..."

# Extract each mermaid code block and export
# You'll need to manually extract each diagram or use this script

cat > /tmp/diagram1.mmd << 'EOF'
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
EOF

echo "Exporting System Architecture Overview..."
mmdc -i /tmp/diagram1.mmd -o docs/architecture/images/01-system-architecture.png -w 2400 -H 1800 -b transparent

echo "✅ Diagrams exported to docs/architecture/images/"
echo ""
echo "To export all diagrams, manually extract each mermaid block from ARCHITECTURE_VISUAL.md"
echo "and run: mmdc -i input.mmd -o output.png -w 2400 -H 1800 -b transparent"
