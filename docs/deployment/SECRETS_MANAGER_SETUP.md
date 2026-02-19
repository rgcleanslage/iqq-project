# AWS Secrets Manager Setup for API Testing

**Date**: February 19, 2026  
**Status**: Complete

## Overview

The GitHub Actions deployment workflows use AWS Secrets Manager to securely store and retrieve credentials for API testing during the verification step.

## Secrets Created

### 1. iqq-dev-cognito-client-default

**ARN**: `arn:aws:secretsmanager:us-east-1:785826687678:secret:iqq-dev-cognito-client-default-BWTMeP`

**Purpose**: Stores Cognito OAuth client credentials for obtaining access tokens

**Format**:
```json
{
  "client_id": "YOUR_CLIENT_ID",
  "client_secret": "YOUR_CLIENT_SECRET"
}
```

**Tags**:
- Environment: dev
- ManagedBy: Manual
- Purpose: APITesting

### 2. iqq-dev-api-key-default

**ARN**: `arn:aws:secretsmanager:us-east-1:785826687678:secret:iqq-dev-api-key-default-XDd9No`

**Purpose**: Stores the default API key for API Gateway requests

**Format**:
```json
{
  "api_key": "YOUR_API_KEY"
}
```

**Tags**:
- Environment: dev
- ManagedBy: Manual
- Purpose: APITesting

## Usage in Workflows

The `deploy-version.yml` workflow uses these secrets in the "Verify Service Deployments" step:

```yaml
- name: Get OAuth token
  id: auth
  run: |
    # Get Cognito client credentials
    CLIENT_ID=$(aws secretsmanager get-secret-value \
      --secret-id "iqq-dev-cognito-client-default" \
      --query 'SecretString' --output text | jq -r '.client_id')
    
    CLIENT_SECRET=$(aws secretsmanager get-secret-value \
      --secret-id "iqq-dev-cognito-client-default" \
      --query 'SecretString' --output text | jq -r '.client_secret')
    
    # Get API key
    API_KEY=$(aws secretsmanager get-secret-value \
      --secret-id "iqq-dev-api-key-default" \
      --query 'SecretString' --output text | jq -r '.api_key')
    
    # Get OAuth token
    TOKEN=$(curl -s -X POST "https://${DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -u "${CLIENT_ID}:${CLIENT_SECRET}" \
      -d "grant_type=client_credentials" | jq -r '.access_token')
```

## IAM Permissions Required

The GitHub Actions OIDC role needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:785826687678:secret:iqq-dev-cognito-client-default-*",
        "arn:aws:secretsmanager:us-east-1:785826687678:secret:iqq-dev-api-key-default-*"
      ]
    }
  ]
}
```

## Retrieving Secrets

### Using AWS CLI

```bash
# Get Cognito client credentials
aws secretsmanager get-secret-value \
  --secret-id iqq-dev-cognito-client-default \
  --region us-east-1 \
  --query 'SecretString' --output text | jq .

# Get API key
aws secretsmanager get-secret-value \
  --secret-id iqq-dev-api-key-default \
  --region us-east-1 \
  --query 'SecretString' --output text | jq .
```

### Using AWS Console

1. Navigate to AWS Secrets Manager in the us-east-1 region
2. Search for `iqq-dev-cognito-client-default` or `iqq-dev-api-key-default`
3. Click "Retrieve secret value" to view the credentials

## Updating Secrets

If credentials need to be rotated:

```bash
# Update Cognito client credentials
aws secretsmanager update-secret \
  --secret-id iqq-dev-cognito-client-default \
  --secret-string '{"client_id":"NEW_CLIENT_ID","client_secret":"NEW_CLIENT_SECRET"}' \
  --region us-east-1

# Update API key
aws secretsmanager update-secret \
  --secret-id iqq-dev-api-key-default \
  --secret-string '{"api_key":"NEW_API_KEY"}' \
  --region us-east-1
```

## Security Best Practices

1. **Least Privilege**: Only grant `secretsmanager:GetSecretValue` permission, not `PutSecretValue` or `DeleteSecret`
2. **Rotation**: Consider enabling automatic rotation for production environments
3. **Audit**: Enable CloudTrail logging for secret access
4. **Encryption**: Secrets are encrypted at rest using AWS KMS
5. **Access Control**: Use IAM policies and resource-based policies to restrict access

## Troubleshooting

### Secret Not Found Error

If you see "ResourceNotFoundException" in workflow logs:

1. Verify the secret exists:
   ```bash
   aws secretsmanager list-secrets --region us-east-1 | grep iqq-dev
   ```

2. Check the secret name matches exactly (case-sensitive)

3. Verify the IAM role has `secretsmanager:GetSecretValue` permission

### Empty Values

If secrets return empty values:

1. Check the JSON format is correct:
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id iqq-dev-cognito-client-default \
     --region us-east-1 \
     --query 'SecretString' --output text | jq .
   ```

2. Verify the jq query path matches the JSON structure

### Authentication Failures

If OAuth token requests fail:

1. Verify the Cognito client ID and secret are correct
2. Check the Cognito domain is correct
3. Ensure the client has `client_credentials` grant type enabled
4. Verify the client has the required OAuth scopes

## Related Documentation

- [API Versioning with GitHub Releases](./API_VERSIONING_WITH_GITHUB_RELEASES.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [V5 Deployment Fixes](./V5_DEPLOYMENT_FIXES.md)
