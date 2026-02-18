#!/bin/bash

# Script to test version headers across all four services

set -e

echo "🔍 Testing Version Headers - All Services"
echo "=========================================="
echo ""

# Get credentials
cd iqq-infrastructure
CLIENT_ID=$(terraform output -json cognito_partner_clients | jq -r '.default.client_id')
CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets | jq -r '.default')
API_KEY=$(terraform output -raw default_api_key_value)
cd ..

# Get OAuth token
echo "🔐 Getting OAuth token..."
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

echo "✅ Token obtained"
echo ""

# Test Package Service
echo "📦 Testing Package Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "v1 Package:"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|x-api-|x-correlation|warning):" | head -5

echo ""
echo "v2 Package:"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|x-api-|x-correlation|warning):" | head -5

echo ""
echo ""

# Test Lender Service
echo "🏦 Testing Lender Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "v1 Lender:"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/lender?lenderId=LENDER-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|x-api-|x-correlation|warning):" | head -5

echo ""
echo "v2 Lender:"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/lender?lenderId=LENDER-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|x-api-|x-correlation|warning):" | head -5

echo ""
echo ""

# Test Product Service
echo "🛡️  Testing Product Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "v1 Product:"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/product?productId=PROD-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|x-api-|x-correlation|warning):" | head -5

echo ""
echo "v2 Product:"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/product?productId=PROD-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|x-api-|x-correlation|warning):" | head -5

echo ""
echo ""

# Test Document Service
echo "📄 Testing Document Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "v1 Document:"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/document" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|x-api-|x-correlation|warning):" | head -5

echo ""
echo "v2 Document:"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/document" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|x-api-|x-correlation|warning):" | head -5

echo ""
echo ""
echo "✅ Version Headers Test Complete!"
echo ""
echo "Expected headers for all services:"
echo "  ✓ x-api-version: v1 or v2"
echo "  ✓ x-api-deprecated: false (for stable versions)"
echo "  ✓ x-api-sunset-date: null (for stable versions)"
echo "  ✓ x-correlation-id: <uuid>"
echo ""
