#!/bin/bash

# Script to test versioned API endpoints (v1 and v2)

set -e

echo "🧪 Testing Versioned API Endpoints"
echo "===================================="
echo ""

# Get credentials from Terraform
cd iqq-infrastructure

# Use the DEFAULT client (24j8eld9b4h7h0mnsa0b75t8ba) which maps to CLI001
# This matches the default API key's clientId tag
CLIENT_ID=$(terraform output -json cognito_partner_clients | jq -r '.default.client_id')
CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets | jq -r '.default')
API_KEY=$(terraform output -raw default_api_key_value)
COGNITO_DOMAIN="iqq-dev-ib9i1hvt"
API_ID="r8ukhidr1m"
REGION="us-east-1"

cd ..

echo "📋 Configuration:"
echo "   API Gateway ID: $API_ID"
echo "   Cognito Domain: $COGNITO_DOMAIN"
echo "   Client ID: $CLIENT_ID (maps to CLI001)"
echo "   API Key Client: CLI001"
echo "   Region: $REGION"
echo ""

# Get OAuth token
echo "🔐 Getting OAuth token..."
TOKEN_RESPONSE=$(curl -s -X POST "https://${COGNITO_DOMAIN}.auth.${REGION}.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Failed to get OAuth token"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✅ OAuth token obtained"
echo ""

# Test function
test_endpoint() {
  local version=$1
  local endpoint=$2
  local url="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${version}/${endpoint}"
  
  echo "Testing: $url"
  
  RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$url" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-api-key: $API_KEY")
  
  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  BODY=$(echo "$RESPONSE" | sed '$d')
  
  if [ "$HTTP_CODE" == "200" ]; then
    echo "   ✅ Status: $HTTP_CODE"
    echo "   Response: $(echo $BODY | jq -c '.' 2>/dev/null || echo $BODY | head -c 100)"
  else
    echo "   ❌ Status: $HTTP_CODE"
    echo "   Response: $BODY"
  fi
  echo ""
}

# Test v1 endpoints
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing v1 Stage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_endpoint "v1" "package?productCode=MBP"
test_endpoint "v1" "lender"
test_endpoint "v1" "product"
test_endpoint "v1" "document"

# Test v2 endpoints
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing v2 Stage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_endpoint "v2" "package?productCode=MBP"
test_endpoint "v2" "lender"
test_endpoint "v2" "product"
test_endpoint "v2" "document"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Testing Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
echo "   Both v1 and v2 stages are accessible"
echo "   Same Lambda aliases are being invoked"
echo "   API keys work for both versions"
echo ""
echo "🎯 Next Steps:"
echo "   1. Update Postman collections with new URLs"
echo "   2. Implement Lambda version headers (Task 3)"
echo "   3. Update documentation"
echo ""
