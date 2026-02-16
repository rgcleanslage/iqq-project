#!/bin/bash

# ============================================================================
# API Endpoint Testing Script
# Tests all API Gateway endpoints including HTTP-based provider invocation
# ============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration - Set these environment variables or update with your values
API_URL="${API_URL:-}"  # Set via: export API_URL=your-api-url
API_KEY="${API_KEY:-}"  # Set via: export API_KEY=your-api-key
OAUTH_TOKEN_FILE=".oauth-token.txt"

# Cognito configuration - Get from Terraform outputs
COGNITO_DOMAIN="${COGNITO_DOMAIN:-}"  # Set via: export COGNITO_DOMAIN=your-cognito-domain
CLIENT_ID="${CLIENT_ID:-}"            # Set via: export CLIENT_ID=your-client-id
CLIENT_SECRET="${CLIENT_SECRET:-}"    # Set via: export CLIENT_SECRET=your-client-secret

# Validate required environment variables
if [ -z "$API_URL" ] || [ -z "$API_KEY" ] || [ -z "$COGNITO_DOMAIN" ] || [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "Error: Missing required environment variables"
  echo ""
  echo "Please set the following environment variables:"
  echo "  export API_URL=<your-api-gateway-url>"
  echo "  export API_KEY=<your-api-key>"
  echo "  export COGNITO_DOMAIN=<your-cognito-domain>"
  echo "  export CLIENT_ID=<your-cognito-client-id>"
  echo "  export CLIENT_SECRET=<your-cognito-client-secret>"
  echo ""
  echo "Or get them from Terraform:"
  echo "  cd iqq-infrastructure"
  echo "  export API_URL=\$(terraform output -raw api_gateway_url)"
  echo "  export API_KEY=\$(terraform output -raw default_api_key_value)"
  echo "  export COGNITO_DOMAIN=\$(terraform output -raw cognito_domain)"
  echo "  export CLIENT_ID=\$(terraform output -raw cognito_app_client_id)"
  echo "  export CLIENT_SECRET=\$(terraform output -raw cognito_app_client_secret)"
  echo ""
  exit 1
fi

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
  echo ""
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo ""
}

print_test() {
  echo -e "${YELLOW}Testing: $1${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================
# OAuth Token Management
# ============================================================================

get_oauth_token() {
  print_info "Getting OAuth token from Cognito..."
  
  TOKEN=$(curl -s -X POST "https://${COGNITO_DOMAIN}/oauth2/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "${CLIENT_ID}:${CLIENT_SECRET}" \
    -d "grant_type=client_credentials" | jq -r '.access_token')

  if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    print_error "Failed to get OAuth token"
    return 1
  fi

  # Save token to file
  echo "$TOKEN" > "$OAUTH_TOKEN_FILE"
  print_success "OAuth token obtained and saved"
  return 0
}

load_oauth_token() {
  if [ -f "$OAUTH_TOKEN_FILE" ]; then
    TOKEN=$(cat "$OAUTH_TOKEN_FILE")
    print_info "Loaded OAuth token from file"
  else
    get_oauth_token
  fi
}

# ============================================================================
# Test Functions
# ============================================================================

test_endpoint() {
  local name=$1
  local endpoint=$2
  local method=$3
  local query=$4
  local expected_status=${5:-200}
  
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  print_test "$name"
  echo -e "  ${BLUE}${method} ${endpoint}${query}${NC}"
  
  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X ${method} "${API_URL}${endpoint}${query}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "x-api-key: ${API_KEY}" \
    -H "Content-Type: application/json")
  
  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')
  
  if [ "$HTTP_CODE" == "$expected_status" ]; then
    print_success "Status: ${HTTP_CODE}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    
    # Pretty print JSON if valid
    if echo "$BODY" | jq '.' > /dev/null 2>&1; then
      echo "$BODY" | jq '.' | head -20
      
      # Check for specific fields in package response
      if [[ "$endpoint" == "/package" ]]; then
        validate_package_response "$BODY"
      fi
    else
      echo "$BODY"
    fi
  else
    print_error "Status: ${HTTP_CODE} (expected ${expected_status})"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo "$BODY"
  fi
  echo ""
}

validate_package_response() {
  local body=$1
  
  # Check for provider quotes
  local quote_count=$(echo "$body" | jq -r '.providerQuotes | length')
  if [ "$quote_count" -gt 0 ]; then
    print_success "Found ${quote_count} provider quotes"
    
    # List providers
    echo "$body" | jq -r '.providerQuotes[] | "  - \(.provider) (\(.providerId)): $\(.premium)"'
    
    # Check for best quote
    local best_provider=$(echo "$body" | jq -r '.bestQuote.provider // "none"')
    if [ "$best_provider" != "none" ]; then
      print_success "Best quote from: ${best_provider}"
    fi
    
    # Check for errors
    local error_count=$(echo "$body" | jq -r '.summary.failedProviders // 0')
    if [ "$error_count" -gt 0 ]; then
      print_error "Failed providers: ${error_count}"
      echo "$body" | jq -r '.summary.errors[]? | "  - \(.provider): \(.error)"'
    fi
  else
    print_error "No provider quotes found"
  fi
}

test_unauthorized_access() {
  print_test "Unauthorized Access (no token)"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${API_URL}/lender" \
    -H "x-api-key: ${API_KEY}")
  
  if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
    print_success "Correctly rejected: ${HTTP_CODE}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    print_error "Expected 401/403, got: ${HTTP_CODE}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
  echo ""
}

test_invalid_api_key() {
  print_test "Invalid API Key (with valid OAuth token)"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${API_URL}/lender" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "x-api-key: invalid-key-12345")
  
  # With REQUEST authorizer, invalid API key should be rejected
  if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
    print_success "Correctly rejected: ${HTTP_CODE}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    print_error "Unexpected status: ${HTTP_CODE}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
  echo ""
}

test_missing_api_key() {
  print_test "Missing API Key (with valid OAuth token)"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${API_URL}/lender" \
    -H "Authorization: Bearer ${TOKEN}")
  
  # With REQUEST authorizer, API key is now required
  if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
    print_success "Correctly rejected (API key required): ${HTTP_CODE}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    print_error "Unexpected status: ${HTTP_CODE}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
  echo ""
}

# ============================================================================
# Main Test Execution
# ============================================================================

main() {
  print_header "iQQ API Endpoint Tests"
  
  print_info "API URL: ${API_URL}"
  print_info "Testing HTTP-based provider invocation"
  echo ""
  
  # Load or get OAuth token
  load_oauth_token
  
  # Security Tests
  print_header "Security Tests"
  test_unauthorized_access
  test_missing_api_key
  test_invalid_api_key
  
  # Endpoint Tests
  print_header "Endpoint Tests"
  
  test_endpoint \
    "Lender Service" \
    "/lender" \
    "GET" \
    ""
  
  test_endpoint \
    "Product Service" \
    "/product" \
    "GET" \
    ""
  
  test_endpoint \
    "Document Service" \
    "/document" \
    "GET" \
    ""
  
  # Package Service Tests (with HTTP provider invocation)
  print_header "Package Service Tests (HTTP Provider Invocation)"
  
  test_endpoint \
    "Package Service - Default Parameters" \
    "/package" \
    "GET" \
    ""
  
  test_endpoint \
    "Package Service - MBP Product" \
    "/package" \
    "GET" \
    "?productCode=MBP&coverageType=COMPREHENSIVE&vehicleValue=25000&term=36"
  
  test_endpoint \
    "Package Service - GAP Product" \
    "/package" \
    "GET" \
    "?productCode=GAP&coverageType=STANDARD&vehicleValue=30000&term=48"
  
  test_endpoint \
    "Package Service - High Value Vehicle" \
    "/package" \
    "GET" \
    "?productCode=MBP&coverageType=PREMIUM&vehicleValue=75000&term=60"
  
  # Summary
  print_header "Test Summary"
  
  echo -e "Total Tests:  ${TOTAL_TESTS}"
  echo -e "Passed:       ${GREEN}${PASSED_TESTS}${NC}"
  echo -e "Failed:       ${RED}${FAILED_TESTS}${NC}"
  
  if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    print_success "All tests passed!"
    echo ""
    print_info "HTTP-based provider invocation is working correctly"
    exit 0
  else
    echo ""
    print_error "Some tests failed"
    exit 1
  fi
}

# Run main function
main "$@"
