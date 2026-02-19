#!/bin/bash

# Cleanup Orphaned Lambda Aliases
# This script identifies and optionally deletes Lambda aliases that are not managed by CloudFormation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Lambda Alias Cleanup Utility${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Configuration
SERVICES=("package" "lender" "product" "document")
ENVIRONMENT="${1:-dev}"
REGION="${AWS_REGION:-us-east-1}"
DRY_RUN="${2:-true}"

if [ "$DRY_RUN" == "false" ]; then
  echo -e "${YELLOW}⚠️  DRY RUN DISABLED - Will delete orphaned aliases!${NC}"
  echo -e "${YELLOW}   Press Ctrl+C within 5 seconds to cancel...${NC}"
  sleep 5
else
  echo -e "${GREEN}ℹ️  Running in DRY RUN mode (no changes will be made)${NC}"
fi

echo ""

# Function to check if alias is managed by CloudFormation
check_alias_management() {
  local function_name=$1
  local alias_name=$2
  local stack_name=$3
  
  # Check if alias exists in CloudFormation stack resources
  local managed=$(aws cloudformation describe-stack-resources \
    --stack-name "$stack_name" \
    --region "$REGION" \
    --query "StackResources[?ResourceType=='AWS::Lambda::Alias' && contains(PhysicalResourceId, '$alias_name')].LogicalResourceId" \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$managed" ]; then
    echo "managed"
  else
    echo "orphaned"
  fi
}

# Process each service
for service in "${SERVICES[@]}"; do
  FUNCTION_NAME="iqq-${service}-service-${ENVIRONMENT}"
  STACK_NAME="iqq-${service}-service-${ENVIRONMENT}"
  
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Service: ${service}${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  # Check if function exists
  if ! aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" &>/dev/null; then
    echo -e "${YELLOW}⚠️  Function not found: $FUNCTION_NAME${NC}"
    echo ""
    continue
  fi
  
  # Check stack status
  STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "DOES_NOT_EXIST")
  
  echo -e "Stack Status: ${YELLOW}$STACK_STATUS${NC}"
  
  # Get all aliases
  ALIASES=$(aws lambda list-aliases \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query 'Aliases[].Name' \
    --output text 2>/dev/null || echo "")
  
  if [ -z "$ALIASES" ]; then
    echo -e "${GREEN}✅ No aliases found${NC}"
    echo ""
    continue
  fi
  
  echo -e "Found aliases: ${YELLOW}$ALIASES${NC}"
  echo ""
  
  # Check each alias
  ORPHANED_COUNT=0
  MANAGED_COUNT=0
  
  for alias in $ALIASES; do
    STATUS=$(check_alias_management "$FUNCTION_NAME" "$alias" "$STACK_NAME")
    
    if [ "$STATUS" == "orphaned" ]; then
      echo -e "  ${RED}❌ $alias - ORPHANED (not managed by CloudFormation)${NC}"
      ORPHANED_COUNT=$((ORPHANED_COUNT + 1))
      
      if [ "$DRY_RUN" == "false" ]; then
        echo -e "     ${YELLOW}Deleting...${NC}"
        aws lambda delete-alias \
          --function-name "$FUNCTION_NAME" \
          --name "$alias" \
          --region "$REGION"
        echo -e "     ${GREEN}✅ Deleted${NC}"
      else
        echo -e "     ${BLUE}Would delete: aws lambda delete-alias --function-name $FUNCTION_NAME --name $alias${NC}"
      fi
    else
      echo -e "  ${GREEN}✅ $alias - Managed by CloudFormation${NC}"
      MANAGED_COUNT=$((MANAGED_COUNT + 1))
    fi
  done
  
  echo ""
  echo -e "Summary:"
  echo -e "  Managed: ${GREEN}$MANAGED_COUNT${NC}"
  echo -e "  Orphaned: ${RED}$ORPHANED_COUNT${NC}"
  echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Cleanup Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" == "true" ]; then
  echo -e "${YELLOW}To actually delete orphaned aliases, run:${NC}"
  echo -e "${YELLOW}  bash $0 $ENVIRONMENT false${NC}"
fi
