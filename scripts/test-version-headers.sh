#!/bin/bash

# Script to test version headers in API responses

set -e

echo "🔍 Testing Version Headers"
echo "=========================="
echo ""

# Get credentials
cd iqq-infrastructure
CLIENT_ID=$(terraform output -json cognito_partner_clients | jq -r '.default.client_id')
CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets | jq -r '.default')
API_KEY=$(terraform output -raw default_api_key_value)
cd ..

# Get OAuth token
TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

echo "📋 Testing v1 Package Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|X-API-|X-Correlation|Warning):"

echo ""
echo ""
echo "📋 Testing v2 Package Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|X-API-|X-Correlation|Warning):"

echo ""
echo ""
echo "📋 Testing v1 Document Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v1/document" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|X-API-|X-Correlation|Warning):"

echo ""
echo ""
echo "📋 Testing v2 Document Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -i -X GET "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v2/document" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" 2>&1 | grep -E "^(HTTP|X-API-|X-Correlation|Warning):"

echo ""
echo ""
echo "✅ Version Headers Test Complete!"
echo ""
echo "Expected headers:"
echo "  - X-API-Version: v1 or v2"
echo "  - X-API-Deprecated: false (for stable versions)"
echo "  - X-API-Sunset-Date: null (for stable versions)"
echo "  - X-Correlation-ID: <uuid>"
echo ""
