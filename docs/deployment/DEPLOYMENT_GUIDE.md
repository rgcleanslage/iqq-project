# iQQ API Modernization - Deployment Guide

Complete guide to deploy the working reference architecture.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.5 installed
- AWS SAM CLI installed
- Node.js 20.x installed

## Architecture Overview

This reference architecture demonstrates:
- **4 TypeScript Lambda microservices** (lender, package, product, document)
- **AWS SAM** for Lambda deployment
- **Terraform** for infrastructure (API Gateway, Cognito, Lambda versioning)
- **Cognito** for OAuth 2.0 authentication
- **API Gateway** with stage variables for version routing
- **CloudWatch + X-Ray** for observability

## Deployment Steps

### Step 1: Deploy Lambda Functions (SAM)

Deploy each microservice using AWS SAM. Start with the lender service:

```bash
# Navigate to lender service
cd iqq-lender-service

# Install dependencies
npm install

# Build TypeScript
npm run build

# Build SAM package
sam build

# Deploy (first time - guided)
sam deploy --guided --parameter-overrides Environment=dev

# Follow prompts:
# - Stack Name: iqq-lender-service-dev
# - AWS Region: us-east-1
# - Confirm changes: Y
# - Allow SAM CLI IAM role creation: Y
# - Save arguments to configuration file: Y
```

**Repeat for other microservices:**
```bash
cd ../iqq-package-service
# (Same steps - create similar structure)

cd ../iqq-product-service
# (Same steps - create similar structure)

cd ../iqq-document-service
# (Same steps - create similar structure)
```

### Step 2: Create Terraform Backend (One-time setup)

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://iqq-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket iqq-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name iqq-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 3: Deploy Infrastructure (Terraform)

```bash
cd iqq-infrastructure

# Initialize Terraform
terraform init

# Plan infrastructure changes
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply infrastructure
terraform apply -var-file=environments/dev/terraform.tfvars

# Save outputs
terraform output > outputs.txt
```

### Step 4: Test the API

#### Get Cognito Token

```bash
# Get Cognito details from Terraform outputs
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_app_client_id)
CLIENT_SECRET=$(terraform output -raw cognito_app_client_secret)
API_URL=$(terraform output -raw api_gateway_url)

# Get OAuth token
TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=testuser,PASSWORD=TestPass123! \
  --query 'AuthenticationResult.AccessToken' \
  --output text)
```

#### Test Lender Endpoint

```bash
# Call lender endpoint
curl -X GET "${API_URL}/dev/lender?lenderId=LENDER-123" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "lenderId": "LENDER-123",
  "lenderName": "Premium Auto Finance",
  "lenderType": "Captive",
  ...
}
```

## Current Implementation Status

### ✅ Completed (Working Example)

1. **iqq-lender-service** - Fully implemented
   - TypeScript Lambda handler
   - SAM template
   - Unit tests with Jest
   - Structured logging
   - X-Ray tracing
   - Domain models

2. **iqq-infrastructure** - Complete Terraform
   - Cognito module (User Pool + App Client)
   - API Gateway module (4 resources + authorizer)
   - Lambda versioning module (aliases)
   - Dev environment configuration

### 🚧 Template Only (Copy from Lender)

3. **iqq-package-service** - Copy lender service structure
4. **iqq-product-service** - Copy lender service structure
5. **iqq-document-service** - Copy lender service structure

## Replicating Microservices

To create the remaining 3 microservices, copy the lender service:

```bash
# Copy lender service to package service
cp -r iqq-lender-service iqq-package-service

# Update package.json name
sed -i '' 's/iqq-lender-service/iqq-package-service/g' iqq-package-service/package.json

# Update template.yaml
sed -i '' 's/lender/package/g' iqq-package-service/template.yaml
sed -i '' 's/Lender/Package/g' iqq-package-service/template.yaml

# Update source code
# Edit src/index.ts to return package-specific data
# Edit src/models/ to define package models
```

Repeat for product and document services.

## Observability

### CloudWatch Logs

```bash
# View lender service logs
aws logs tail /aws/lambda/iqq-lender-service-dev --follow
```

### X-Ray Traces

1. Go to AWS Console → X-Ray → Service Map
2. View end-to-end traces from API Gateway → Lambda

### CloudWatch Dashboards

Terraform creates CloudWatch dashboards automatically. View in AWS Console → CloudWatch → Dashboards.

## Version Management

### Update Lambda Alias

```bash
# Publish new version
aws lambda publish-version --function-name iqq-lender-service-dev

# Update alias to point to new version
aws lambda update-alias \
  --function-name iqq-lender-service-dev \
  --name v2 \
  --function-version 2
```

### Switch API Gateway Stage

```bash
# Update stage variable to route to v2
aws apigateway update-stage \
  --rest-api-id <API_ID> \
  --stage-name prod \
  --patch-operations op=replace,path=/variables/lambdaAlias,value=v2
```

## Cleanup

```bash
# Delete Terraform infrastructure
cd iqq-infrastructure
terraform destroy -var-file=environments/dev/terraform.tfvars

# Delete SAM stacks
aws cloudformation delete-stack --stack-name iqq-lender-service-dev
aws cloudformation delete-stack --stack-name iqq-package-service-dev
aws cloudformation delete-stack --stack-name iqq-product-service-dev
aws cloudformation delete-stack --stack-name iqq-document-service-dev

# Delete Terraform backend (optional)
aws s3 rb s3://iqq-terraform-state --force
aws dynamodb delete-table --table-name iqq-terraform-locks
```

## Troubleshooting

### Lambda Function Not Found

**Error**: Terraform can't find Lambda function

**Solution**: Deploy SAM stack first, then run Terraform

### Cognito Authentication Failed

**Error**: 401 Unauthorized

**Solution**: Ensure you're using a valid JWT token from Cognito

### API Gateway 403 Error

**Error**: Missing Authentication Token

**Solution**: Include `Authorization: Bearer <token>` header

## Next Steps

1. **Implement remaining microservices** (package, product, document)
2. **Add Postman collections** for API testing
3. **Setup CI/CD pipelines** (GitHub Actions or Azure DevOps)
4. **Implement Epic 2** (Package microservice with Step Functions)

## Support

For issues or questions:
- Review CloudWatch Logs for Lambda errors
- Check X-Ray traces for performance issues
- Verify Terraform state is consistent
