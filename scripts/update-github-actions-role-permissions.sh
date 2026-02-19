#!/bin/bash

# Script to update GitHub Actions IAM role with Lambda versioning permissions
# This adds permissions needed for the deploy workflows to manage Lambda versions and aliases

set -e

ROLE_NAME="github-actions-sam-dev"
POLICY_NAME="LambdaVersioningPolicy"

echo "🔐 Updating IAM role permissions for GitHub Actions"
echo "   Role: $ROLE_NAME"
echo ""

# Create policy document
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LambdaVersioning",
      "Effect": "Allow",
      "Action": [
        "lambda:PublishVersion",
        "lambda:CreateAlias",
        "lambda:UpdateAlias",
        "lambda:GetAlias",
        "lambda:ListAliases",
        "lambda:ListVersionsByFunction"
      ],
      "Resource": [
        "arn:aws:lambda:us-east-1:785826687678:function:iqq-*-service-*"
      ]
    },
    {
      "Sid": "LambdaInvoke",
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": [
        "arn:aws:lambda:us-east-1:785826687678:function:iqq-*-service-*",
        "arn:aws:lambda:us-east-1:785826687678:function:iqq-*-service-*:*"
      ]
    }
  ]
}
EOF
)

echo "📝 Policy document:"
echo "$POLICY_DOCUMENT" | jq .
echo ""

# Check if policy already exists
EXISTING_POLICIES=$(aws iam list-role-policies \
  --role-name "$ROLE_NAME" \
  --query 'PolicyNames' \
  --output text 2>/dev/null || echo "")

if echo "$EXISTING_POLICIES" | grep -q "$POLICY_NAME"; then
  echo "⚠️  Policy $POLICY_NAME already exists, updating..."
  
  aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT"
  
  echo "✅ Policy updated successfully"
else
  echo "➕ Creating new policy..."
  
  aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT"
  
  echo "✅ Policy created successfully"
fi

echo ""
echo "🔍 Verifying policy..."
aws iam get-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --query 'PolicyDocument' \
  --output json | jq .

echo ""
echo "✅ IAM role permissions updated successfully"
echo ""
echo "The role now has permissions to:"
echo "  • Publish Lambda versions"
echo "  • Create and update Lambda aliases"
echo "  • Get alias information"
echo "  • Invoke Lambda functions with aliases"
echo ""
echo "You can now re-run the deployment workflow."
