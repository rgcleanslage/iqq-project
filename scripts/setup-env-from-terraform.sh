#!/bin/bash

# ============================================================================
# Setup Environment Variables from Terraform Outputs
# Exports all necessary credentials for testing scripts
# ============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
  echo ""
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo ""
}

# Check if we're in the right directory
if [ ! -d "iqq-infrastructure" ]; then
  print_error "iqq-infrastructure directory not found"
  echo "Please run this script from the project root directory"
  exit 1
fi

cd iqq-infrastructure

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
  print_error "Terraform not initialized"
  echo "Please run: cd iqq-infrastructure && terraform init"
  exit 1
fi

print_header "Extracting Terraform Outputs"

# Get outputs
print_info "Getting API Gateway URL..."
export API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")

print_info "Getting Cognito configuration..."
export COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "")
export CLIENT_ID=$(terraform output -raw cognito_app_client_id 2>/dev/null || echo "")
export CLIENT_SECRET=$(terraform output -raw cognito_app_client_secret 2>/dev/null || echo "")

# Get Cognito domain from AWS if user pool ID is available
if [ -n "$COGNITO_USER_POOL_ID" ]; then
  print_info "Fetching Cognito domain from AWS..."
  COGNITO_DOMAIN_PREFIX=$(aws cognito-idp describe-user-pool \
    --user-pool-id "$COGNITO_USER_POOL_ID" \
    --region us-east-1 \
    --query 'UserPool.Domain' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$COGNITO_DOMAIN_PREFIX" ]; then
    export COGNITO_DOMAIN="${COGNITO_DOMAIN_PREFIX}.auth.us-east-1.amazoncognito.com"
  else
    export COGNITO_DOMAIN=""
  fi
else
  export COGNITO_DOMAIN=""
fi

print_info "Getting API key..."
export API_KEY=$(terraform output -raw default_api_key_value 2>/dev/null || echo "")

cd ..

# Validate outputs
print_header "Validation"

MISSING=0

if [ -z "$API_URL" ]; then
  print_error "API_URL not found"
  MISSING=1
else
  print_success "API_URL: ${API_URL}"
fi

if [ -z "$COGNITO_DOMAIN" ]; then
  print_error "COGNITO_DOMAIN not found"
  MISSING=1
else
  print_success "COGNITO_DOMAIN: ${COGNITO_DOMAIN}"
fi

if [ -z "$CLIENT_ID" ]; then
  print_error "CLIENT_ID not found"
  MISSING=1
else
  print_success "CLIENT_ID: ${CLIENT_ID}"
fi

if [ -z "$CLIENT_SECRET" ]; then
  print_error "CLIENT_SECRET not found"
  MISSING=1
else
  print_success "CLIENT_SECRET: [hidden]"
fi

if [ -z "$API_KEY" ]; then
  print_error "API_KEY not found"
  MISSING=1
else
  print_success "API_KEY: ${API_KEY:0:8}..."
fi

if [ $MISSING -eq 1 ]; then
  echo ""
  print_error "Some outputs are missing. Have you deployed the infrastructure?"
  echo "Run: cd iqq-infrastructure && terraform apply"
  exit 1
fi

# Create .env file
print_header "Creating .env File"

cat > .env <<EOF
# Auto-generated from Terraform outputs
# Source this file: source .env

export API_URL="${API_URL}"
export COGNITO_DOMAIN="${COGNITO_DOMAIN}"
export CLIENT_ID="${CLIENT_ID}"
export CLIENT_SECRET="${CLIENT_SECRET}"
export API_KEY="${API_KEY}"
EOF

print_success "Created .env file"

# Add .env to .gitignore if not already there
if ! grep -q "^\.env$" .gitignore 2>/dev/null; then
  echo ".env" >> .gitignore
  print_success "Added .env to .gitignore"
fi

print_header "Setup Complete"

echo "Environment variables have been exported to your current shell."
echo ""
echo "To use in a new shell, run:"
echo "  source .env"
echo ""
echo "Or export manually:"
echo "  export API_URL=\"${API_URL}\""
echo "  export COGNITO_DOMAIN=\"${COGNITO_DOMAIN}\""
echo "  export CLIENT_ID=\"${CLIENT_ID}\""
echo "  export CLIENT_SECRET=\"${CLIENT_SECRET}\""
echo "  export API_KEY=\"${API_KEY}\""
echo ""
echo "Now you can run:"
echo "  ./scripts/test-api-endpoints.sh"
echo ""
