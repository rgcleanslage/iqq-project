#!/bin/bash

# Deploy a single service with proper cleanup and error handling

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check arguments
if [ $# -lt 1 ]; then
  echo -e "${RED}Usage: $0 <service-name> [environment]${NC}"
  echo -e "${YELLOW}Example: $0 product dev${NC}"
  exit 1
fi

SERVICE=$1
ENVIRONMENT=${2:-dev}
REGION=${AWS_REGION:-us-east-1}
API_GATEWAY_ID=${API_GATEWAY_ID:-r8ukhidr1m}

SERVICE_DIR="iqq-${SERVICE}-service"
FUNCTION_NAME="iqq-${SERVICE}-service-${ENVIRONMENT}"
STACK_NAME="iqq-${SERVICE}-service-${ENVIRONMENT}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Deploying ${SERVICE} Service${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Service: ${YELLOW}${SERVICE}${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Region: ${YELLOW}${REGION}${NC}"
echo -e "Stack: ${YELLOW}${STACK_NAME}${NC}"
echo ""

# Check if service directory exists
if [ ! -d "$SERVICE_DIR" ]; then
  echo -e "${RED}❌ Service directory not found: $SERVICE_DIR${NC}"
  exit 1
fi

cd "$SERVICE_DIR"

# Step 1: Check stack status
echo -e "${CYAN}📊 Checking stack status...${NC}"
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "DOES_NOT_EXIST")

echo -e "Current status: ${YELLOW}$STACK_STATUS${NC}"

# Step 2: Clean up orphaned aliases if stack is in bad state
if [[ "$STACK_STATUS" == "UPDATE_ROLLBACK_COMPLETE" ]] || [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]]; then
  echo -e "${YELLOW}⚠️  Stack is in rollback state, cleaning up aliases...${NC}"
  
  for alias in v1 v2 latest; do
    echo -e "  Deleting alias: $alias"
    aws lambda delete-alias \
      --function-name "$FUNCTION_NAME" \
      --name "$alias" \
      --region "$REGION" 2>/dev/null || echo "    Alias not found (OK)"
  done
  
  echo -e "${GREEN}✅ Cleanup complete${NC}"
fi

# Step 3: Build
echo ""
echo -e "${CYAN}🔨 Building SAM application...${NC}"
sam build

# Step 4: Deploy
echo ""
echo -e "${CYAN}🚀 Deploying to AWS...${NC}"
sam deploy \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --parameter-overrides "Environment=$ENVIRONMENT ApiGatewayId=$API_GATEWAY_ID"

# Step 5: Verify
echo ""
echo -e "${CYAN}✅ Verifying deployment...${NC}"

# Check stack status
FINAL_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text)

echo -e "Final status: ${YELLOW}$FINAL_STATUS${NC}"

# Check aliases
echo ""
echo -e "${CYAN}📋 Lambda aliases:${NC}"
aws lambda list-aliases \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --query 'Aliases[*].[Name,FunctionVersion]' \
  --output table

# Check permissions
echo ""
echo -e "${CYAN}🔐 Lambda permissions:${NC}"
POLICY=$(aws lambda get-policy \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --query 'Policy' \
  --output text 2>/dev/null || echo "{}")

PERMISSION_COUNT=$(echo "$POLICY" | jq '.Statement | length' 2>/dev/null || echo "0")
echo -e "Permissions configured: ${GREEN}$PERMISSION_COUNT${NC}"

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$FINAL_STATUS" == "UPDATE_COMPLETE" ] || [ "$FINAL_STATUS" == "CREATE_COMPLETE" ]; then
  echo -e "${GREEN}✅ Deployment successful!${NC}"
  echo ""
  echo -e "Next steps:"
  echo -e "  1. Test the endpoint: curl https://$API_GATEWAY_ID.execute-api.$REGION.amazonaws.com/v1/$SERVICE"
  echo -e "  2. Check logs: aws logs tail /aws/lambda/$FUNCTION_NAME --region $REGION --follow"
else
  echo -e "${RED}❌ Deployment failed or incomplete${NC}"
  echo -e "Check CloudFormation events: aws cloudformation describe-stack-events --stack-name $STACK_NAME --region $REGION"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
