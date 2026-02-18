#!/bin/bash

# Script to verify and fix Cognito OAuth configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Cognito OAuth Configuration Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

USER_POOL_ID="us-east-1_Wau5rEb2N"
CLIENT_ID="25oa5u3vup2jmhl270e7shudkl"
REGION="us-east-1"

echo -e "${YELLOW}Step 1: Checking current app client configuration...${NC}"
echo ""

# Get current configuration
CURRENT_CONFIG=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id "$USER_POOL_ID" \
  --client-id "$CLIENT_ID" \
  --region "$REGION" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to get app client configuration${NC}"
    echo "$CURRENT_CONFIG"
    exit 1
fi

echo -e "${GREEN}✓ App client found${NC}"
echo ""

# Check OAuth flows
OAUTH_FLOWS=$(echo "$CURRENT_CONFIG" | jq -r '.UserPoolClient.AllowedOAuthFlows[]' 2>/dev/null)
OAUTH_ENABLED=$(echo "$CURRENT_CONFIG" | jq -r '.UserPoolClient.AllowedOAuthFlowsUserPoolClient' 2>/dev/null)
OAUTH_SCOPES=$(echo "$CURRENT_CONFIG" | jq -r '.UserPoolClient.AllowedOAuthScopes[]' 2>/dev/null)

echo "Current Configuration:"
echo "  OAuth Flows Enabled: $OAUTH_ENABLED"
echo "  OAuth Flows: $OAUTH_FLOWS"
echo "  OAuth Scopes: $OAUTH_SCOPES"
echo ""

# Check if configuration is correct
NEEDS_UPDATE=false

if [ "$OAUTH_ENABLED" != "true" ]; then
    echo -e "${YELLOW}⚠ OAuth flows not enabled${NC}"
    NEEDS_UPDATE=true
fi

if ! echo "$OAUTH_FLOWS" | grep -q "client_credentials"; then
    echo -e "${YELLOW}⚠ client_credentials flow not configured${NC}"
    NEEDS_UPDATE=true
fi

if ! echo "$OAUTH_SCOPES" | grep -q "iqq-api/read"; then
    echo -e "${YELLOW}⚠ iqq-api/read scope not configured${NC}"
    NEEDS_UPDATE=true
fi

if [ "$NEEDS_UPDATE" = false ]; then
    echo -e "${GREEN}✓ Configuration is correct!${NC}"
    echo ""
    echo "Your app client is properly configured for OAuth 2.0 Client Credentials flow."
    echo ""
    
    # Show client secret
    echo -e "${YELLOW}Step 2: Getting client secret...${NC}"
    CLIENT_SECRET=$(echo "$CURRENT_CONFIG" | jq -r '.UserPoolClient.ClientSecret')
    
    if [ "$CLIENT_SECRET" != "null" ] && [ -n "$CLIENT_SECRET" ]; then
        echo -e "${GREEN}✓ Client secret found${NC}"
        echo ""
        echo "Client ID: $CLIENT_ID"
        echo "Client Secret: $CLIENT_SECRET"
        echo ""
        echo "Use these credentials in Postman or cURL."
    else
        echo -e "${RED}✗ No client secret found${NC}"
        echo "The app client may need to be recreated with generate_secret=true"
    fi
    
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 2: Updating app client configuration...${NC}"
echo ""

# Update the app client
UPDATE_RESULT=$(aws cognito-idp update-user-pool-client \
  --user-pool-id "$USER_POOL_ID" \
  --client-id "$CLIENT_ID" \
  --allowed-o-auth-flows "client_credentials" \
  --allowed-o-auth-scopes "iqq-api/read" "iqq-api/write" \
  --allowed-o-auth-flows-user-pool-client \
  --supported-identity-providers "COGNITO" \
  --region "$REGION" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to update app client${NC}"
    echo "$UPDATE_RESULT"
    exit 1
fi

echo -e "${GREEN}✓ App client updated successfully${NC}"
echo ""

# Verify the update
echo -e "${YELLOW}Step 3: Verifying configuration...${NC}"
echo ""

VERIFY_CONFIG=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id "$USER_POOL_ID" \
  --client-id "$CLIENT_ID" \
  --region "$REGION" \
  --output json)

OAUTH_FLOWS=$(echo "$VERIFY_CONFIG" | jq -r '.UserPoolClient.AllowedOAuthFlows[]')
OAUTH_ENABLED=$(echo "$VERIFY_CONFIG" | jq -r '.UserPoolClient.AllowedOAuthFlowsUserPoolClient')
OAUTH_SCOPES=$(echo "$VERIFY_CONFIG" | jq -r '.UserPoolClient.AllowedOAuthScopes[]')

echo "Updated Configuration:"
echo "  OAuth Flows Enabled: $OAUTH_ENABLED"
echo "  OAuth Flows: $OAUTH_FLOWS"
echo "  OAuth Scopes: $OAUTH_SCOPES"
echo ""

if [ "$OAUTH_ENABLED" = "true" ] && echo "$OAUTH_FLOWS" | grep -q "client_credentials"; then
    echo -e "${GREEN}✓ Configuration verified!${NC}"
    echo ""
    
    # Show client secret
    CLIENT_SECRET=$(echo "$VERIFY_CONFIG" | jq -r '.UserPoolClient.ClientSecret')
    
    if [ "$CLIENT_SECRET" != "null" ] && [ -n "$CLIENT_SECRET" ]; then
        echo "Client ID: $CLIENT_ID"
        echo "Client Secret: $CLIENT_SECRET"
        echo ""
        echo -e "${GREEN}You can now use these credentials in Postman!${NC}"
    else
        echo -e "${YELLOW}⚠ No client secret found${NC}"
        echo "You may need to regenerate the app client with a secret."
    fi
else
    echo -e "${RED}✗ Configuration verification failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "1. Copy the Client Secret above"
echo "2. In Postman, update your environment variable 'clientSecret'"
echo "3. Use the 'Get OAuth Token (Working)' request"
echo "4. Test the API endpoints"
echo ""
