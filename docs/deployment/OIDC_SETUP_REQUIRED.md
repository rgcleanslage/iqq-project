# OIDC Setup Required for iqq-project Repository

**Date**: February 19, 2026  
**Status**: ⚠️ Action Required  
**Priority**: High

## Issue

The `add-new-version` workflow failed during the v4 test because the AWS IAM role's OIDC trust relationship doesn't include the `iqq-project` repository.

**Error**:
```
Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

## What Worked ✅

Despite the OIDC failure, the workflow successfully completed these tasks:

1. ✅ Created 5 release branches (release/v4)
   - iqq-package-service
   - iqq-lender-service
   - iqq-product-service
   - iqq-document-service
   - iqq-infrastructure

2. ✅ Created 5 pull requests
   - iqq-project (root)
   - iqq-package-service
   - iqq-lender-service
   - iqq-product-service
   - iqq-document-service

3. ✅ Updated version-policy.json in all repositories
4. ✅ Generated migration guide
5. ✅ Updated workflow dropdowns

## What Failed ❌

The `deploy-infrastructure` job failed because it couldn't assume the AWS role:

- ❌ API Gateway stage creation (AWS CLI)
- ❌ Lambda permissions (AWS CLI)
- ❌ Infrastructure verification

## Root Cause

The AWS IAM role `arn:aws:iam::785826687678:role/github-actions-sam-dev` has an OIDC trust relationship that only includes the service repositories, not the root `iqq-project` repository.

**Current Trust Policy** (assumed):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::785826687678:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:rgcleanslage/iqq-package-service:*",
            "repo:rgcleanslage/iqq-lender-service:*",
            "repo:rgcleanslage/iqq-product-service:*",
            "repo:rgcleanslage/iqq-document-service:*",
            "repo:rgcleanslage/iqq-infrastructure:*"
          ]
        }
      }
    }
  ]
}
```

## Solution

Update the IAM role's trust policy to include the `iqq-project` repository.

### Option 1: Add iqq-project to Existing Role

**Updated Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::785826687678:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:rgcleanslage/iqq-project:*",
            "repo:rgcleanslage/iqq-package-service:*",
            "repo:rgcleanslage/iqq-lender-service:*",
            "repo:rgcleanslage/iqq-product-service:*",
            "repo:rgcleanslage/iqq-document-service:*",
            "repo:rgcleanslage/iqq-infrastructure:*"
          ]
        }
      }
    }
  ]
}
```

**Steps**:
1. Go to AWS IAM Console
2. Navigate to Roles → `github-actions-sam-dev`
3. Click "Trust relationships" tab
4. Click "Edit trust policy"
5. Add `"repo:rgcleanslage/iqq-project:*"` to the StringLike condition
6. Click "Update policy"

### Option 2: Use Wildcard (Less Secure)

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:rgcleanslage/*:*"
}
```

**Note**: This allows any repository in the `rgcleanslage` organization to assume the role. Less secure but more flexible.

### Option 3: Create Separate Role for iqq-project

Create a new role specifically for the iqq-project repository with limited permissions:

**Role Name**: `github-actions-iqq-project`

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::785826687678:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:rgcleanslage/iqq-project:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

**Permissions Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:DELETE",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "lambda:GetPolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

## Recommended Approach

**Option 1** is recommended because:
- ✅ Minimal changes required
- ✅ Uses existing role and permissions
- ✅ Maintains security (specific repository)
- ✅ Quick to implement

## Testing After Fix

Once the trust policy is updated, test with:

```bash
# Test with v5 (or re-run v4)
gh workflow run add-new-version.yml \
  --repo rgcleanslage/iqq-project \
  -f new_version=v5 \
  -f status=planned
```

**Expected Results**:
- ✅ All 14 jobs complete successfully
- ✅ API Gateway stage created
- ✅ Lambda permissions added
- ✅ Stage URL returned
- ✅ Infrastructure PR shows "Automatically Deployed"

## Verification Commands

After updating the trust policy, verify it works:

```bash
# Check the role trust policy
aws iam get-role --role-name github-actions-sam-dev \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json

# Should show iqq-project in the StringLike condition
```

## Alternative: Manual Infrastructure Deployment

If OIDC setup is delayed, you can manually deploy infrastructure for new versions:

```bash
# Get API Gateway ID
API_ID=$(aws apigateway get-rest-apis \
  --query 'items[?name==`iqq-api-dev`].id' \
  --output text)

# Get latest deployment
DEPLOYMENT_ID=$(aws apigateway get-deployments \
  --rest-api-id "$API_ID" \
  --query 'items[0].id' \
  --output text)

# Create stage
aws apigateway create-stage \
  --rest-api-id "$API_ID" \
  --stage-name v4 \
  --deployment-id "$DEPLOYMENT_ID" \
  --variables lambdaAlias=v4

# Add Lambda permissions (repeat for each service)
for SERVICE in package lender product document; do
  aws lambda add-permission \
    --function-name "iqq-${SERVICE}-service-dev" \
    --statement-id "AllowAPIGatewayInvokeV4" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:us-east-1:*:${API_ID}/v4/GET/${SERVICE}" \
    --qualifier v4
done
```

## Impact

**Current State**:
- ✅ Workflow automation works (PRs, branches, config updates)
- ❌ Infrastructure deployment requires manual steps
- ⚠️ Workflow shows as "failed" even though most tasks succeed

**After Fix**:
- ✅ Full end-to-end automation
- ✅ Infrastructure deployed automatically
- ✅ No manual steps required
- ✅ Workflow shows as "success"

## Timeline

**Priority**: High  
**Effort**: 5 minutes  
**Impact**: Enables full workflow automation

## Related Documentation

- `docs/deployment/GITHUB_OIDC_SETUP.md` - Original OIDC setup guide
- `docs/deployment/ADD_NEW_VERSION_WORKFLOW_GUIDE.md` - Workflow documentation
- `docs/deployment/AWS_CLI_MIGRATION_COMPLETE.md` - AWS CLI migration details

---

**Action Required**: Update IAM role trust policy to include `iqq-project` repository  
**Blocking**: Full automation of add-new-version workflow  
**Workaround**: Manual infrastructure deployment (commands provided above)

