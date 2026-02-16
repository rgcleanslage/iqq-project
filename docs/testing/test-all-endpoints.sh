#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get OAuth token
echo "Getting OAuth token..."
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "25oa5u3vup2jmhl270e7shudkl:oilctiluurgblk7212h8jb9lntjoefqb6n56rer3iuks9642el9" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
  echo -e "${RED}Failed to get OAuth token${NC}"
  exit 1
fi

echo -e "${GREEN}✓ OAuth token obtained${NC}"
echo ""

# Configuration - Set these environment variables
API_URL="${API_URL:-}"  # Set via: export API_URL=your-api-url
API_KEY="${API_KEY:-}"  # Set via: export API_KEY=your-api-key

if [ -z "$API_URL" ] || [ -z "$API_KEY" ]; then
  echo "Error: API_URL and API_KEY environment variables must be set"
  echo "Get them from Terraform: cd iqq-infrastructure && terraform output"
  exit 1
fi

# Test function
test_endpoint() {
  local endpoint=$1
  local method=$2
  local query=$3
  
  echo -e "${YELLOW}Testing ${method} ${endpoint}${query}${NC}"
  
  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X ${method} "${API_URL}${endpoint}${query}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json")
  
  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')
  
  if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Status: ${HTTP_CODE}${NC}"
    echo "$BODY" | jq '.'
  else
    echo -e "${RED}✗ Status: ${HTTP_CODE}${NC}"
    echo "$BODY"
  fi
  echo ""
}

# Test all endpoints
echo "=========================================="
echo "API Endpoint Tests"
echo "=========================================="
echo ""

test_endpoint "/lender" "GET" ""
test_endpoint "/product" "GET" ""
test_endpoint "/package" "GET" "?productCode=MBP&coverageType=COMPREHENSIVE"
test_endpoint "/document" "GET" ""

echo "=========================================="
echo "All tests completed"
echo "=========================================="
