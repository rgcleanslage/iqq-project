#!/bin/bash

# Script to retrieve API keys from Terraform output
# Usage: ./get-api-keys.sh

set -e

echo "=========================================="
echo "Retrieving API Keys from Terraform"
echo "=========================================="
echo ""

cd iqq-infrastructure

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
  echo "❌ Error: terraform.tfstate not found"
  echo "Please run 'terraform apply' first"
  exit 1
fi

echo "📋 API Gateway Configuration:"
echo "----------------------------"
terraform output -raw api_gateway_url
echo ""
echo ""

echo "🔑 Default API Key (Testing):"
echo "----------------------------"
terraform output -raw default_api_key_value
echo ""
echo ""

if terraform output partner_a_api_key_value &>/dev/null; then
  echo "🔑 Partner A API Key (Premium Plan):"
  echo "----------------------------"
  terraform output -raw partner_a_api_key_value
  echo ""
  echo ""
  
  echo "🔑 Partner B API Key (Standard Plan):"
  echo "----------------------------"
  terraform output -raw partner_b_api_key_value
  echo ""
  echo ""
else
  echo "ℹ️  Partner keys not created (create_partner_keys = false)"
  echo ""
fi

echo "📊 Usage Plans:"
echo "----------------------------"
echo "Standard Plan: 10,000 req/month, 50 req/sec, 100 burst"
echo "Premium Plan:  100,000 req/month, 200 req/sec, 500 burst"
echo ""

echo "✅ Done! Save these API keys securely."
echo ""
echo "💡 Test with:"
echo "   ./test-with-api-key.sh"
