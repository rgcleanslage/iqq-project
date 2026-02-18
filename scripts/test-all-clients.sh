#!/bin/bash

# Test all Cognito app clients with their corresponding API keys

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_BASE_URL="https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev"
COGNITO_DOMAIN="iqq-dev-ib9i1hvt"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing All Client Credentials${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to test a client
test_client() {
    local CLIENT_NAME=$1
    local CLIENT_ID=$2
    local CLIENT_SECRET=$3
    local API_KEY=$4
    
    echo -e "${YELLOW}Testing ${CLIENT_NAME}...${NC}"
    echo "Client ID: ${CLIENT_ID}"
    echo ""
    
    # Get OAuth token
    echo "  → Getting OAuth token..."
    TOKEN_RESPONSE=$(curl -s -X POST "https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -u "${CLIENT_ID}:${CLIENT_SECRET}" \
      -d "grant_type=client_credentials&scope=iqq-api/read")
    
    TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
    
    if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
        echo -e "${RED}  ✗ Failed to get token${NC}"
        echo "  Response: $TOKEN_RESPONSE"
        return 1
    fi
    
    echo -e "${GREEN}  ✓ Token obtained${NC}"
    
    # Test lender endpoint
    echo "  → Testing /lender endpoint..."
    LENDER_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_BASE_URL}/lender" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "x-api-key: ${API_KEY}")
    
    HTTP_STATUS=$(echo "$LENDER_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    LENDER_BODY=$(echo "$LENDER_RESPONSE" | sed '/HTTP_STATUS:/d')
    
    if [ "$HTTP_STATUS" == "200" ]; then
        LENDER_NAME=$(echo "$LENDER_BODY" | jq -r '.lenderName')
        echo -e "${GREEN}  ✓ Lender endpoint: ${LENDER_NAME}${NC}"
    else
        echo -e "${RED}  ✗ Lender endpoint failed (HTTP $HTTP_STATUS)${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ ${CLIENT_NAME} working correctly${NC}"
    echo ""
    return 0
}

# Get credentials from Terraform
echo -e "${YELLOW}Retrieving credentials from Terraform...${NC}"
echo ""

cd iqq-infrastructure

# Default client
DEFAULT_CLIENT_ID=$(terraform output -json cognito_partner_clients | jq -r '.default.client_id')
DEFAULT_CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets | jq -r '.default')
DEFAULT_API_KEY=$(terraform output -raw default_api_key_value)

# Partner A
PARTNER_A_CLIENT_ID=$(terraform output -json cognito_partner_clients | jq -r '.partner_a.client_id')
PARTNER_A_CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets | jq -r '.partner_a')
PARTNER_A_API_KEY=$(terraform output -raw partner_a_api_key_value)

# Partner B
PARTNER_B_CLIENT_ID=$(terraform output -json cognito_partner_clients | jq -r '.partner_b.client_id')
PARTNER_B_CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets | jq -r '.partner_b')
PARTNER_B_API_KEY=$(terraform output -raw partner_b_api_key_value)

# Legacy client
LEGACY_CLIENT_ID=$(terraform output -raw cognito_app_client_id)
LEGACY_CLIENT_SECRET=$(terraform output -raw cognito_app_client_secret)

cd ..

echo -e "${GREEN}✓ Credentials retrieved${NC}"
echo ""

# Test all clients
FAILED=0

test_client "Default Client" "$DEFAULT_CLIENT_ID" "$DEFAULT_CLIENT_SECRET" "$DEFAULT_API_KEY" || FAILED=$((FAILED+1))
test_client "Partner A Client" "$PARTNER_A_CLIENT_ID" "$PARTNER_A_CLIENT_SECRET" "$PARTNER_A_API_KEY" || FAILED=$((FAILED+1))
test_client "Partner B Client" "$PARTNER_B_CLIENT_ID" "$PARTNER_B_CLIENT_SECRET" "$PARTNER_B_API_KEY" || FAILED=$((FAILED+1))
test_client "Legacy Client (with default API key)" "$LEGACY_CLIENT_ID" "$LEGACY_CLIENT_SECRET" "$DEFAULT_API_KEY" || FAILED=$((FAILED+1))

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All clients tested successfully!${NC}"
    echo ""
    echo "Clients tested:"
    echo "  • Default Client"
    echo "  • Partner A Client"
    echo "  • Partner B Client"
    echo "  • Legacy Client"
    echo ""
    echo "All clients can authenticate and access the API."
else
    echo -e "${RED}✗ $FAILED client(s) failed${NC}"
    exit 1
fi
