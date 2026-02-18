#!/bin/bash

# Test script for client preferences functionality
# Tests provider filtering based on client-specific preferences

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧪 Testing Client Preferences System${NC}\n"

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo -e "${RED}❌ .env file not found. Run setup-env-from-terraform.sh first${NC}"
  exit 1
fi

# Check required variables
if [ -z "$API_URL" ] || [ -z "$API_KEY" ]; then
  echo -e "${RED}❌ Required environment variables not set${NC}"
  exit 1
fi

# Get OAuth token
echo -e "${YELLOW}🔐 Getting OAuth token...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST "https://${COGNITO_DOMAIN}/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}❌ Failed to get access token${NC}"
  echo $TOKEN_RESPONSE | jq .
  exit 1
fi

echo -e "${GREEN}✅ Got access token${NC}\n"

# Test 1: Without client preferences (all providers)
echo -e "${YELLOW}Test 1: Package request WITHOUT client preferences${NC}"
echo "Expected: All 3 providers (Client, Route66, APCO)"

RESPONSE1=$(curl -s -X GET "${API_URL}/package?productCode=MBP&coverageType=COMPREHENSIVE" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}")

QUOTE_COUNT1=$(echo $RESPONSE1 | jq '.summary.totalQuotes')
PROVIDERS1=$(echo $RESPONSE1 | jq -r '.providerQuotes[].provider' | tr '\n' ', ' | sed 's/,$//')

echo "Result: $QUOTE_COUNT1 quotes from: $PROVIDERS1"

if [ "$QUOTE_COUNT1" == "3" ]; then
  echo -e "${GREEN}✅ Test 1 PASSED${NC}\n"
else
  echo -e "${RED}❌ Test 1 FAILED - Expected 3 quotes, got $QUOTE_COUNT1${NC}\n"
fi

# Test 2: With CLI001 preferences (blocked APCO, max 2)
echo -e "${YELLOW}Test 2: Package request WITH CLI001 preferences${NC}"
echo "Expected: 2 providers (Client, Route66) - APCO blocked"

RESPONSE2=$(curl -s -X GET "${API_URL}/package?productCode=MBP&coverageType=COMPREHENSIVE&clientId=CLI001" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}")

QUOTE_COUNT2=$(echo $RESPONSE2 | jq '.summary.totalQuotes')
PROVIDERS2=$(echo $RESPONSE2 | jq -r '.providerQuotes[].provider' | tr '\n' ', ' | sed 's/,$//')
HAS_APCO=$(echo $PROVIDERS2 | grep -i "APCO" || echo "")

echo "Result: $QUOTE_COUNT2 quotes from: $PROVIDERS2"

if [ "$QUOTE_COUNT2" == "2" ] && [ -z "$HAS_APCO" ]; then
  echo -e "${GREEN}✅ Test 2 PASSED${NC}\n"
else
  echo -e "${RED}❌ Test 2 FAILED - Expected 2 quotes without APCO${NC}\n"
fi

# Test 3: With CLI002 preferences (only Client and Route66 allowed)
echo -e "${YELLOW}Test 3: Package request WITH CLI002 preferences${NC}"
echo "Expected: 2 providers (Client, Route66) - only these allowed"

RESPONSE3=$(curl -s -X GET "${API_URL}/package?productCode=MBP&coverageType=COMPREHENSIVE&clientId=CLI002" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}")

QUOTE_COUNT3=$(echo $RESPONSE3 | jq '.summary.totalQuotes')
PROVIDERS3=$(echo $RESPONSE3 | jq -r '.providerQuotes[].provider' | tr '\n' ', ' | sed 's/,$//')
HAS_APCO3=$(echo $PROVIDERS3 | grep -i "APCO" || echo "")

echo "Result: $QUOTE_COUNT3 quotes from: $PROVIDERS3"

if [ "$QUOTE_COUNT3" == "2" ] && [ -z "$HAS_APCO3" ]; then
  echo -e "${GREEN}✅ Test 3 PASSED${NC}\n"
else
  echo -e "${RED}❌ Test 3 FAILED - Expected 2 quotes (Client and Route66 only)${NC}\n"
fi

# Test 4: Non-existent client (should use all providers)
echo -e "${YELLOW}Test 4: Package request with non-existent client${NC}"
echo "Expected: All 3 providers (no preferences found)"

RESPONSE4=$(curl -s -X GET "${API_URL}/package?productCode=MBP&coverageType=COMPREHENSIVE&clientId=CLI999" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}")

QUOTE_COUNT4=$(echo $RESPONSE4 | jq '.summary.totalQuotes')
PROVIDERS4=$(echo $RESPONSE4 | jq -r '.providerQuotes[].provider' | tr '\n' ', ' | sed 's/,$//')

echo "Result: $QUOTE_COUNT4 quotes from: $PROVIDERS4"

if [ "$QUOTE_COUNT4" == "3" ]; then
  echo -e "${GREEN}✅ Test 4 PASSED${NC}\n"
else
  echo -e "${RED}❌ Test 4 FAILED - Expected 3 quotes, got $QUOTE_COUNT4${NC}\n"
fi

# Summary
echo -e "${YELLOW}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}═══════════════════════════════════════${NC}"
echo "Test 1 (No preferences): $QUOTE_COUNT1 quotes"
echo "Test 2 (CLI001 - blocked APCO): $QUOTE_COUNT2 quotes"
echo "Test 3 (CLI002 - allowed only): $QUOTE_COUNT3 quotes"
echo "Test 4 (Non-existent client): $QUOTE_COUNT4 quotes"
echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"

# Check if all tests passed
if [ "$QUOTE_COUNT1" == "3" ] && [ "$QUOTE_COUNT2" == "2" ] && [ "$QUOTE_COUNT3" == "2" ] && [ "$QUOTE_COUNT4" == "3" ]; then
  echo -e "${GREEN}✅ All tests PASSED!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some tests FAILED${NC}"
  exit 1
fi
