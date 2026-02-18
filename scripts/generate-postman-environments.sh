#!/bin/bash

# Script to generate Postman environment files from templates with actual credentials
# This keeps secrets out of git while making it easy to set up Postman

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_API_DIR="$SCRIPT_DIR/../docs/api"
INFRA_DIR="$SCRIPT_DIR/../iqq-infrastructure"

echo "=========================================="
echo "Generating Postman Environment Files"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -d "$INFRA_DIR" ]; then
    echo "❌ Error: iqq-infrastructure directory not found"
    echo "Please run this script from the repository root"
    exit 1
fi

# Change to infrastructure directory to run terraform commands
cd "$INFRA_DIR"

echo "Retrieving credentials from Terraform..."
echo ""

# Get Default Client credentials
echo "1. Default Client (CLI001)..."
DEFAULT_CLIENT_ID=$(terraform output -json cognito_partner_clients 2>/dev/null | jq -r '.default.client_id' || echo "")
DEFAULT_CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets 2>/dev/null | jq -r '.default' || echo "")
DEFAULT_API_KEY=$(terraform output -raw default_api_key_value 2>/dev/null || echo "")

if [ -z "$DEFAULT_CLIENT_ID" ] || [ -z "$DEFAULT_CLIENT_SECRET" ] || [ -z "$DEFAULT_API_KEY" ]; then
    echo "⚠️  Warning: Could not retrieve Default Client credentials from Terraform"
    echo "   Make sure Terraform has been applied in iqq-infrastructure/"
else
    echo "   ✓ Retrieved Default Client credentials"
fi

# Get Partner A credentials
echo "2. Partner A Client (CLI002)..."
PARTNER_A_CLIENT_ID=$(terraform output -json cognito_partner_clients 2>/dev/null | jq -r '.partner_a.client_id' || echo "")
PARTNER_A_CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets 2>/dev/null | jq -r '.partner_a' || echo "")
PARTNER_A_API_KEY=$(terraform output -raw partner_a_api_key_value 2>/dev/null || echo "")

if [ -z "$PARTNER_A_CLIENT_ID" ] || [ -z "$PARTNER_A_CLIENT_SECRET" ] || [ -z "$PARTNER_A_API_KEY" ]; then
    echo "⚠️  Warning: Could not retrieve Partner A credentials from Terraform"
else
    echo "   ✓ Retrieved Partner A credentials"
fi

# Get Partner B credentials
echo "3. Partner B Client (CLI003)..."
PARTNER_B_CLIENT_ID=$(terraform output -json cognito_partner_clients 2>/dev/null | jq -r '.partner_b.client_id' || echo "")
PARTNER_B_CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets 2>/dev/null | jq -r '.partner_b' || echo "")
PARTNER_B_API_KEY=$(terraform output -raw partner_b_api_key_value 2>/dev/null || echo "")

if [ -z "$PARTNER_B_CLIENT_ID" ] || [ -z "$PARTNER_B_CLIENT_SECRET" ] || [ -z "$PARTNER_B_API_KEY" ]; then
    echo "⚠️  Warning: Could not retrieve Partner B credentials from Terraform"
else
    echo "   ✓ Retrieved Partner B credentials"
fi

echo ""
echo "Generating environment files..."
echo ""

# Generate Default Client environment
if [ -n "$DEFAULT_CLIENT_ID" ]; then
    cat "$DOCS_API_DIR/postman-environment-default.template.json" | \
        jq --arg clientId "$DEFAULT_CLIENT_ID" \
           --arg clientSecret "$DEFAULT_CLIENT_SECRET" \
           --arg apiKey "$DEFAULT_API_KEY" \
           '.values[2].value = $clientId | 
            .values[3].value = $clientSecret | 
            .values[4].value = $apiKey' \
        > "$DOCS_API_DIR/postman-environment-default.json"
    echo "✓ Generated: postman-environment-default.json"
else
    echo "⚠️  Skipped: postman-environment-default.json (missing credentials)"
fi

# Generate Partner A environment
if [ -n "$PARTNER_A_CLIENT_ID" ]; then
    cat "$DOCS_API_DIR/postman-environment-partner-a.template.json" | \
        jq --arg clientId "$PARTNER_A_CLIENT_ID" \
           --arg clientSecret "$PARTNER_A_CLIENT_SECRET" \
           --arg apiKey "$PARTNER_A_API_KEY" \
           '.values[2].value = $clientId | 
            .values[3].value = $clientSecret | 
            .values[4].value = $apiKey' \
        > "$DOCS_API_DIR/postman-environment-partner-a.json"
    echo "✓ Generated: postman-environment-partner-a.json"
else
    echo "⚠️  Skipped: postman-environment-partner-a.json (missing credentials)"
fi

# Generate Partner B environment
if [ -n "$PARTNER_B_CLIENT_ID" ]; then
    cat "$DOCS_API_DIR/postman-environment-partner-b.template.json" | \
        jq --arg clientId "$PARTNER_B_CLIENT_ID" \
           --arg clientSecret "$PARTNER_B_CLIENT_SECRET" \
           --arg apiKey "$PARTNER_B_API_KEY" \
           '.values[2].value = $clientId | 
            .values[3].value = $clientSecret | 
            .values[4].value = $apiKey' \
        > "$DOCS_API_DIR/postman-environment-partner-b.json"
    echo "✓ Generated: postman-environment-partner-b.json"
else
    echo "⚠️  Skipped: postman-environment-partner-b.json (missing credentials)"
fi

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "Generated files are in: docs/api/"
echo ""
echo "⚠️  IMPORTANT: These files contain secrets and are excluded from git"
echo ""
echo "To use in Postman:"
echo "1. Open Postman"
echo "2. Click 'Import'"
echo "3. Select the generated environment files"
echo "4. Select an environment and start testing"
echo ""
