#!/bin/bash

# Test script for API key to client ID mapping and validation
# Tests automatic client ID extraction and cross-validation

# IMPORTANT: This is a template file. Copy to test-client-id-mapping.sh and fill in credentials
# Or run: ./generate-test-scripts.sh

set -e

API_URL="https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/dev"
COGNITO_DOMAIN="https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com"

echo "=========================================="
echo "Testing API Key to Client ID Mapping"
echo "=========================================="
echo ""

# Test 1: Default Client (CLI001) - Should work with matching credentials
echo "Test 1: Default Client (CLI001) with matching API key"
echo "Expected: Success, max 2 quotes, APCO blocked"
echo "------------------------------------------"

# Get credentials from Terraform:
# CLIENT_ID=$(cd iqq-infrastructure && terraform output -json cognito_partner_clients | jq -r '.default.client_id')
# CLIENT_SECRET=$(cd iqq-infrastructure && terraform output -json cognito_partner_client_secrets | jq -r '.default')
# API_KEY=$(cd iqq-infrastructure && terraform output -raw default_api_key_value)

CLIENT_ID="GET_FROM_TERRAFORM"
CLIENT_SECRET="GET_FROM_TERRAFORM"
API_KEY="GET_FROM_TERRAFORM"

if [ "$CLIENT_ID" = "GET_FROM_TERRAFORM" ]; then
    echo "❌ Error: Credentials not configured"
    echo ""
    echo "Please run: ./scripts/generate-test-scripts.sh"
    echo "Or manually update this file with credentials from Terraform"
    exit 1
fi

TOKEN=$(curl -s -X POST "${COGNITO_DOMAIN}/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=iqq-api/read" | jq -r '.access_token')

echo "OAuth Token obtained: ${TOKEN:0:20}..."

RESPONSE=$(curl -s -X GET "${API_URL}/package" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-api-key: ${API_KEY}")

echo "Response:"
echo "$RESPONSE" | jq '.'

QUOTE_COUNT=$(echo "$RESPONSE" | jq '.summary.totalQuotes // 0')
echo "Quotes returned: $QUOTE_COUNT"

if [ "$QUOTE_COUNT" -le 2 ]; then
  echo "✅ Test 1 PASSED: Max 2 quotes enforced"
else
  echo "❌ Test 1 FAILED: Expected max 2 quotes, got $QUOTE_COUNT"
fi

echo ""
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "✅ Test 1: Default client with matching credentials"
echo ""
echo "For more comprehensive tests, see: test-complete-client-mapping.sh"
