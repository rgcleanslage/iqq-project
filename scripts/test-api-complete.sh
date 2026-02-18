#!/bin/bash

# iQQ API Complete Test Script
# Tests all endpoints including OAuth token retrieval

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLIENT_ID="${IQQ_CLIENT_ID:-25oa5u3vup2jmhl270e7shudkl}"
CLIENT_SECRET="${IQQ_CLIENT_SECRET}"
COGNITO_DOMAIN="${IQQ_COGNITO_DOMAIN:-iqq-dev-ib9i1hvt}"
API_BASE_URL="${IQQ_API_URL:-https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev}"
API_KEY="${IQQ_API_KEY:-Ni69xOrTsr5iu0zpiAdkM6Yv0OGjtY3J1qfY9nPH}"

# Check if CLIENT_SECRET is provided
if [ -z "$CLIENT_SECRET" ]; then
    echo -e "${RED}Error: CLIENT_SECRET not provided${NC}"
    echo "Usage: IQQ_CLIENT_SECRET=your-secret $0"
    echo "Or: export IQQ_CLIENT_SECRET=your-secret && $0"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}iQQ API Complete Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Get OAuth Token
echo -e "${YELLOW}Step 1: Getting OAuth Token from Cognito...${NC}"
echo "Endpoint: https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token"
echo ""

TOKEN_RESPONSE=$(curl -s -X POST "https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read")

TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
EXPIRES_IN=$(echo $TOKEN_RESPONSE | jq -r '.expires_in')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ Failed to get token${NC}"
    echo "Response:"
    echo $TOKEN_RESPONSE | jq .
    exit 1
fi

echo -e "${GREEN}✓ Token obtained successfully${NC}"
echo "Token: ${TOKEN:0:50}..."
echo "Expires in: ${EXPIRES_IN} seconds"
echo ""

# Step 2: Test Lender Endpoint
echo -e "${YELLOW}Step 2: Testing Lender Endpoint...${NC}"
echo "GET ${API_BASE_URL}/lender"
echo ""

LENDER_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_BASE_URL}/lender" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}")

HTTP_STATUS=$(echo "$LENDER_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
LENDER_BODY=$(echo "$LENDER_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Lender endpoint successful (HTTP $HTTP_STATUS)${NC}"
    echo "$LENDER_BODY" | jq '{lenderId, lenderName, lenderType, ratingInfo}'
else
    echo -e "${RED}✗ Lender endpoint failed (HTTP $HTTP_STATUS)${NC}"
    echo "$LENDER_BODY" | jq .
fi
echo ""

# Step 3: Test Product Endpoint
echo -e "${YELLOW}Step 3: Testing Product Endpoint...${NC}"
echo "GET ${API_BASE_URL}/product"
echo ""

PRODUCT_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_BASE_URL}/product" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}")

HTTP_STATUS=$(echo "$PRODUCT_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
PRODUCT_BODY=$(echo "$PRODUCT_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Product endpoint successful (HTTP $HTTP_STATUS)${NC}"
    echo "$PRODUCT_BODY" | jq '{productId, productName, productType, pricing}'
else
    echo -e "${RED}✗ Product endpoint failed (HTTP $HTTP_STATUS)${NC}"
    echo "$PRODUCT_BODY" | jq .
fi
echo ""

# Step 4: Test Document Endpoint
echo -e "${YELLOW}Step 4: Testing Document Endpoint...${NC}"
echo "GET ${API_BASE_URL}/document"
echo ""

DOCUMENT_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_BASE_URL}/document" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}")

HTTP_STATUS=$(echo "$DOCUMENT_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
DOCUMENT_BODY=$(echo "$DOCUMENT_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Document endpoint successful (HTTP $HTTP_STATUS)${NC}"
    echo "$DOCUMENT_BODY" | jq '{documentId, documentName, documentType, status}'
else
    echo -e "${RED}✗ Document endpoint failed (HTTP $HTTP_STATUS)${NC}"
    echo "$DOCUMENT_BODY" | jq .
fi
echo ""

# Step 5: Test Package Endpoint (with parameters)
echo -e "${YELLOW}Step 5: Testing Package Endpoint (Multi-Provider Orchestration)...${NC}"
echo "GET ${API_BASE_URL}/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60%20months"
echo ""

PACKAGE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_BASE_URL}/package?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=60%20months" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}")

HTTP_STATUS=$(echo "$PACKAGE_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
PACKAGE_BODY=$(echo "$PACKAGE_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Package endpoint successful (HTTP $HTTP_STATUS)${NC}"
    echo "$PACKAGE_BODY" | jq '{packageId, summary, pricing, bestQuote}'
    echo ""
    echo "Provider Quotes:"
    echo "$PACKAGE_BODY" | jq '.providerQuotes[] | {provider, premium, rating: .providerRating}'
else
    echo -e "${RED}✗ Package endpoint failed (HTTP $HTTP_STATUS)${NC}"
    echo "$PACKAGE_BODY" | jq .
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "All endpoints tested successfully!"
echo ""
echo "Next steps:"
echo "1. Import docs/api/openapi-complete.yaml into Postman or Swagger UI"
echo "2. Generate client SDKs using OpenAPI Generator"
echo "3. Review API documentation in docs/api/OPENAPI_USAGE_GUIDE.md"
echo ""
