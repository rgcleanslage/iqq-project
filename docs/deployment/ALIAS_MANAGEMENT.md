# Lambda Alias Management Guide

## Overview

This guide explains how Lambda aliases are managed in the iQQ API versioning system and how to handle conflicts when aliases already exist.

## Architecture

### Alias Ownership

Lambda aliases are managed by **AWS SAM (CloudFormation)**, not Terraform:

- **SAM manages**: Lambda functions, aliases, and function permissions
- **Terraform manages**: API Gateway, stages, and stage variables

### Why SAM Manages Aliases

1. **Atomic deployments**: Aliases are deployed with the Lambda function
2. **No manual intervention**: Permissions are created automatically
3. **Consistent state**: CloudFormation tracks all resources

## Common Issues

### Issue: "Alias already exists" Error

**Symptom**: CloudFormation deployment fails with:
```
Resource handler returned message: "Alias already exists: 
arn:aws:lambda:us-east-1:123456789:function:iqq-package-service-dev:v1 
(Service: Lambda, Status Code: 409, Request ID: xxx) 
(HandlerErrorCode: AlreadyExists)"
```

**Cause**: An alias was created manually or by a previous deployment outside of CloudFormation.

**Solution**: Use the cleanup script to identify and remove orphaned aliases.

## Cleanup Script

### Usage

```bash
# Dry run (shows what would be deleted)
bash scripts/cleanup-orphaned-aliases.sh dev

# Actually delete orphaned aliases
bash scripts/cleanup-orphaned-aliases.sh dev false
```

### What It Does

1. Lists all Lambda functions for each service
2. Checks each alias to see if it's managed by CloudFormation
3. Identifies "orphaned" aliases (not in CloudFormation)
4. Optionally deletes orphaned aliases

### Example Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Service: package
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stack Status: UPDATE_ROLLBACK_COMPLETE
Found aliases: v1 v2 latest

  ❌ v1 - ORPHANED (not managed by CloudFormation)
     Would delete: aws lambda delete-alias --function-name iqq-package-service-dev --name v1
  ❌ v2 - ORPHANED (not managed by CloudFormation)
     Would delete: aws lambda delete-alias --function-name iqq-package-service-dev --name v2
  ✅ latest - Managed by CloudFormation

Summary:
  Managed: 1
  Orphaned: 2
```

## Automated Handling in CI/CD

The GitHub Actions deployment workflow includes a pre-deployment check:

```yaml
- name: Check and handle existing aliases
  run: |
    # Checks for orphaned aliases
    # Warns if conflicts are detected
    # Provides remediation commands
```

This step:
- Runs before SAM deployment
- Checks CloudFormation stack status
- Identifies orphaned aliases
- Provides warning messages with remediation steps

## Prevention Strategies

### 1. Always Use SAM for Deployments

Never create aliases manually:

```bash
# ❌ DON'T DO THIS
aws lambda create-alias --function-name iqq-package-service-dev --name v1 --function-version 1

# ✅ DO THIS
# Let SAM create aliases via template.yaml
sam deploy --stack-name iqq-package-service-dev
```

### 2. Use CloudFormation for All Infrastructure

Define aliases in SAM template:

```yaml
Resources:
  PackageFunctionAliasV1:
    Type: AWS::Lambda::Alias
    Properties:
      FunctionName: !Ref PackageFunction
      FunctionVersion: $LATEST
      Name: v1
```

### 3. Clean Up Before Major Changes

Before making significant infrastructure changes:

```bash
# Check for orphaned resources
bash scripts/cleanup-orphaned-aliases.sh dev

# Clean up if needed
bash scripts/cleanup-orphaned-aliases.sh dev false
```

## Troubleshooting

### Stack in UPDATE_ROLLBACK_COMPLETE State

**Problem**: Previous deployment failed and rolled back.

**Solution**:
1. Check for orphaned aliases:
   ```bash
   bash scripts/cleanup-orphaned-aliases.sh dev
   ```

2. Delete orphaned aliases:
   ```bash
   bash scripts/cleanup-orphaned-aliases.sh dev false
   ```

3. Retry deployment:
   ```bash
   bash scripts/trigger-deployments.sh
   ```

### Alias Points to Wrong Version

**Problem**: Alias exists but points to the wrong Lambda version.

**Solution**: CloudFormation will update the alias during deployment. No manual action needed.

### Multiple Aliases with Same Name

**Problem**: Impossible - Lambda doesn't allow duplicate alias names per function.

**Verification**: If you suspect this, list aliases:
```bash
aws lambda list-aliases --function-name iqq-package-service-dev
```

## Best Practices

### 1. Infrastructure as Code

- Define all aliases in SAM templates
- Never create aliases manually
- Use CloudFormation for all infrastructure changes

### 2. Regular Audits

Run cleanup script periodically:
```bash
# Weekly audit
bash scripts/cleanup-orphaned-aliases.sh dev
```

### 3. Monitor Stack Status

Check CloudFormation stack health:
```bash
aws cloudformation describe-stacks \
  --stack-name iqq-package-service-dev \
  --query 'Stacks[0].StackStatus'
```

Healthy states:
- `CREATE_COMPLETE`
- `UPDATE_COMPLETE`

Unhealthy states:
- `UPDATE_ROLLBACK_COMPLETE` - Previous update failed
- `ROLLBACK_COMPLETE` - Initial creation failed

### 4. Use Deployment Scripts

Always use provided scripts:
```bash
# ✅ Good
bash scripts/trigger-deployments.sh

# ❌ Bad
sam deploy --stack-name iqq-package-service-dev
```

## Manual Cleanup Commands

If you need to manually clean up:

```bash
# Delete a specific alias
aws lambda delete-alias \
  --function-name iqq-package-service-dev \
  --name v1 \
  --region us-east-1

# Delete all aliases for a function
for alias in v1 v2 latest; do
  aws lambda delete-alias \
    --function-name iqq-package-service-dev \
    --name $alias \
    --region us-east-1 2>/dev/null || echo "Alias $alias not found"
done
```

## Related Documentation

- [Task 6 Deployment Summary](TASK_6_DEPLOYMENT_SUMMARY.md)
- [GitHub Actions Versioning](GITHUB_ACTIONS_VERSIONING.md)
- [API Versioning Setup](../api/API_VERSIONING_SETUP.md)

## Support

If you encounter issues:

1. Run the cleanup script in dry-run mode
2. Check CloudFormation stack events
3. Review GitHub Actions workflow logs
4. Consult this documentation

For persistent issues, check:
- AWS CloudFormation console
- Lambda function configuration
- CloudWatch logs
