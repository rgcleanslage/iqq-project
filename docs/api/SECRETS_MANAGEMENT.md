# Secrets Management

## Overview
This document explains how secrets (OAuth credentials, API keys) are managed in this repository to prevent accidental exposure.

## What's Excluded from Git

The following files contain secrets and are excluded from version control via `.gitignore`:

### Postman Environment Files
- `docs/api/postman-environment-default.json`
- `docs/api/postman-environment-partner-a.json`
- `docs/api/postman-environment-partner-b.json`

### Test Scripts
- `scripts/test-client-id-mapping.sh`
- `scripts/test-complete-client-mapping.sh`

## What's Included in Git

### Template Files (No Secrets)
- `docs/api/postman-environment-default.template.json`
- `docs/api/postman-environment-partner-a.template.json`
- `docs/api/postman-environment-partner-b.template.json`
- `scripts/test-client-id-mapping.template.sh`

### Generator Scripts
- `scripts/generate-postman-environments.sh` - Generates Postman environment files
- `scripts/generate-test-scripts.sh` - Generates test scripts with credentials

### Documentation (Contains Example Credentials)
- `docs/api/CLIENT_CREDENTIALS_MAPPING.md` - Shows credential structure
- `docs/api/POSTMAN_CLIENT_SETUP.md` - Setup instructions

**Note**: Documentation files contain example credentials for reference purposes. These are development credentials and should be rotated for production use.

## Getting Credentials

All credentials are managed by Terraform and stored in AWS. To retrieve them:

### Option 1: Use Generator Scripts (Recommended)

```bash
# Generate Postman environment files
./scripts/generate-postman-environments.sh

# Generate test scripts
./scripts/generate-test-scripts.sh
```

### Option 2: Manual Retrieval from Terraform

```bash
cd iqq-infrastructure

# Get all client IDs
terraform output -json cognito_partner_clients | jq .

# Get all client secrets (sensitive)
terraform output -json cognito_partner_client_secrets | jq -r 'to_entries[] | "\(.key): \(.value)"'

# Get specific credentials
terraform output -json cognito_partner_clients | jq -r '.default.client_id'
terraform output -json cognito_partner_client_secrets | jq -r '.default'
terraform output -raw default_api_key_value

# Get Partner A credentials
terraform output -json cognito_partner_clients | jq -r '.partner_a.client_id'
terraform output -json cognito_partner_client_secrets | jq -r '.partner_a'
terraform output -raw partner_a_api_key_value

# Get Partner B credentials
terraform output -json cognito_partner_clients | jq -r '.partner_b.client_id'
terraform output -json cognito_partner_client_secrets | jq -r '.partner_b'
terraform output -raw partner_b_api_key_value
```

### Option 3: AWS Console

1. **Cognito Credentials**:
   - Go to AWS Console → Cognito → User Pools
   - Select pool: `iqq-user-pool-dev`
   - Go to "App integration" → "App clients"
   - View client details for client ID
   - Click "Show client secret" for secret

2. **API Keys**:
   - Go to AWS Console → API Gateway
   - Select API: `iqq-api-dev`
   - Go to "API Keys"
   - Click on key name to view value

## Setup Workflow

### For Postman Testing

1. Generate environment files:
   ```bash
   ./scripts/generate-postman-environments.sh
   ```

2. Import into Postman:
   - Open Postman
   - Click "Import"
   - Select generated files from `docs/api/`
   - Files: `postman-environment-*.json`

3. Select environment and test

### For Automated Testing

1. Generate test scripts:
   ```bash
   ./scripts/generate-test-scripts.sh
   ```

2. Run tests:
   ```bash
   ./scripts/test-client-id-mapping.sh
   ./scripts/test-complete-client-mapping.sh
   ```

## Security Best Practices

### DO ✅
- Use generator scripts to create files with credentials
- Keep generated files local (they're in .gitignore)
- Rotate credentials regularly (every 90 days)
- Use different credentials for dev/staging/prod
- Store production credentials in AWS Secrets Manager
- Use IAM roles for CI/CD instead of credentials

### DON'T ❌
- Commit files with real credentials to git
- Share credentials via email or chat
- Use production credentials in development
- Hard-code credentials in application code
- Store credentials in plain text files
- Reuse credentials across environments

## Credential Rotation

To rotate credentials:

### 1. Update Terraform
```bash
cd iqq-infrastructure

# Terraform will generate new secrets
terraform apply
```

### 2. Regenerate Files
```bash
# Regenerate Postman environments
./scripts/generate-postman-environments.sh

# Regenerate test scripts
./scripts/generate-test-scripts.sh
```

### 3. Update Postman
- Re-import environment files in Postman
- Old tokens will be invalidated

### 4. Notify Users
- Inform team members to regenerate their local files
- Update any external integrations

## CI/CD Considerations

For GitHub Actions or other CI/CD:

1. **Don't use credentials** - Use IAM roles with OIDC
2. **If credentials required** - Store in GitHub Secrets
3. **Generate files in CI** - Run generator scripts in pipeline
4. **Never commit** - Ensure .gitignore is respected

Example GitHub Actions:
```yaml
- name: Generate test credentials
  run: |
    cd iqq-infrastructure
    # Authenticate with AWS using OIDC
    ./scripts/generate-test-scripts.sh
    
- name: Run tests
  run: ./scripts/test-complete-client-mapping.sh
```

## Checking for Leaked Secrets

### Before Committing
```bash
# Check what's staged
git diff --cached

# Verify no secrets in staged files
git diff --cached | grep -i "secret\|password\|key"
```

### Scan Repository
```bash
# Install gitleaks (if not installed)
brew install gitleaks

# Scan for secrets
gitleaks detect --source . --verbose
```

### If Secrets Are Committed

1. **Immediately rotate** the exposed credentials
2. **Remove from history**:
   ```bash
   # Use BFG Repo-Cleaner or git-filter-repo
   git filter-repo --path docs/api/postman-environment-default.json --invert-paths
   ```
3. **Force push** (if repository is not shared)
4. **Notify team** if repository is shared

## Environment-Specific Credentials

### Development (Current)
- Managed by Terraform in `iqq-infrastructure`
- Retrieved via generator scripts
- Safe to use for local testing

### Staging (Future)
- Separate Terraform workspace
- Different AWS account recommended
- Separate Cognito user pool

### Production (Future)
- Separate Terraform workspace
- Different AWS account required
- Store in AWS Secrets Manager
- Enable automatic rotation
- Use IAM roles where possible

## Questions?

- **Where are credentials stored?** AWS (Cognito, API Gateway, managed by Terraform)
- **How do I get credentials?** Run generator scripts or use Terraform outputs
- **Can I commit environment files?** No, they're in .gitignore
- **What if I accidentally commit secrets?** Rotate immediately and remove from history
- **How often should I rotate?** Every 90 days minimum, immediately if exposed

## References

- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub: Removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

## Date Created
February 18, 2026

## Last Updated
February 18, 2026
