#!/bin/bash
set -e

# Setup Remote State Infrastructure for Team Collaboration
# This script creates S3 buckets and DynamoDB tables for Terraform and SAM state management

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROJECT_PREFIX="iqq"

echo "=========================================="
echo "Setting up Remote State Infrastructure"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "=========================================="

# 1. Create Terraform State S3 Bucket
TERRAFORM_BUCKET="${PROJECT_PREFIX}-terraform-state-${AWS_ACCOUNT_ID}"
echo ""
echo "Creating Terraform state bucket: $TERRAFORM_BUCKET"

if aws s3 ls "s3://$TERRAFORM_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3api create-bucket \
        --bucket "$TERRAFORM_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>/dev/null || \
    aws s3api create-bucket \
        --bucket "$TERRAFORM_BUCKET" \
        --region "$AWS_REGION" 2>/dev/null
    
    echo "✓ Created bucket: $TERRAFORM_BUCKET"
else
    echo "✓ Bucket already exists: $TERRAFORM_BUCKET"
fi

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket "$TERRAFORM_BUCKET" \
    --versioning-configuration Status=Enabled

echo "✓ Enabled versioning"

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket "$TERRAFORM_BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

echo "✓ Enabled encryption"

# Block public access
aws s3api put-public-access-block \
    --bucket "$TERRAFORM_BUCKET" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✓ Blocked public access"

# Add lifecycle policy to clean up old versions
aws s3api put-bucket-lifecycle-configuration \
    --bucket "$TERRAFORM_BUCKET" \
    --lifecycle-configuration '{
        "Rules": [{
            "ID": "DeleteOldVersions",
            "Status": "Enabled",
            "Filter": {},
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            }
        }]
    }'

echo "✓ Added lifecycle policy"

# 2. Create DynamoDB Table for Terraform State Locking
DYNAMODB_TABLE="${PROJECT_PREFIX}-terraform-locks"
echo ""
echo "Creating DynamoDB table for state locking: $DYNAMODB_TABLE"

if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" 2>&1 | grep -q 'ResourceNotFoundException'; then
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Project,Value=iQQ Key=ManagedBy,Value=Script
    
    echo "✓ Created DynamoDB table: $DYNAMODB_TABLE"
    echo "  Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
else
    echo "✓ DynamoDB table already exists: $DYNAMODB_TABLE"
fi

# 3. Create SAM Deployment Bucket (shared across all SAM services)
SAM_BUCKET="${PROJECT_PREFIX}-sam-deployments-${AWS_ACCOUNT_ID}"
echo ""
echo "Creating SAM deployment bucket: $SAM_BUCKET"

if aws s3 ls "s3://$SAM_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3api create-bucket \
        --bucket "$SAM_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>/dev/null || \
    aws s3api create-bucket \
        --bucket "$SAM_BUCKET" \
        --region "$AWS_REGION" 2>/dev/null
    
    echo "✓ Created bucket: $SAM_BUCKET"
else
    echo "✓ Bucket already exists: $SAM_BUCKET"
fi

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket "$SAM_BUCKET" \
    --versioning-configuration Status=Enabled

echo "✓ Enabled versioning"

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket "$SAM_BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

echo "✓ Enabled encryption"

# Block public access
aws s3api put-public-access-block \
    --bucket "$SAM_BUCKET" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✓ Blocked public access"

# Add lifecycle policy to clean up old artifacts
aws s3api put-bucket-lifecycle-configuration \
    --bucket "$SAM_BUCKET" \
    --lifecycle-configuration '{
        "Rules": [{
            "ID": "DeleteOldArtifacts",
            "Status": "Enabled",
            "Filter": {},
            "Expiration": {
                "Days": 30
            },
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 7
            }
        }]
    }'

echo "✓ Added lifecycle policy"

# 4. Summary
echo ""
echo "=========================================="
echo "✓ Remote State Infrastructure Setup Complete!"
echo "=========================================="
echo ""
echo "Terraform Backend Configuration:"
echo "  Bucket: $TERRAFORM_BUCKET"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  Region: $AWS_REGION"
echo ""
echo "SAM Deployment Configuration:"
echo "  Bucket: $SAM_BUCKET"
echo "  Region: $AWS_REGION"
echo ""
echo "Next Steps:"
echo "1. Update iqq-infrastructure/main.tf to use S3 backend"
echo "2. Set SAM_DEPLOYMENT_BUCKET secret in GitHub: $SAM_BUCKET"
echo "3. Run 'terraform init -migrate-state' to migrate existing state"
echo ""
echo "GitHub Secret Command:"
echo "  echo '$SAM_BUCKET' | gh secret set SAM_DEPLOYMENT_BUCKET --repo rgcleanslage/iqq-infrastructure"
echo "  echo '$SAM_BUCKET' | gh secret set SAM_DEPLOYMENT_BUCKET --repo rgcleanslage/iqq-providers"
echo "  echo '$SAM_BUCKET' | gh secret set SAM_DEPLOYMENT_BUCKET --repo rgcleanslage/iqq-lender-service"
echo "  echo '$SAM_BUCKET' | gh secret set SAM_DEPLOYMENT_BUCKET --repo rgcleanslage/iqq-package-service"
echo "  echo '$SAM_BUCKET' | gh secret set SAM_DEPLOYMENT_BUCKET --repo rgcleanslage/iqq-product-service"
echo "  echo '$SAM_BUCKET' | gh secret set SAM_DEPLOYMENT_BUCKET --repo rgcleanslage/iqq-document-service"
echo ""
