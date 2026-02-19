# Quick Start: Testing AWS CLI Automation

**Purpose**: Quick reference for testing the enhanced add-new-version workflow  
**Status**: Ready to test  
**Estimated Time**: 15-20 minutes

## Prerequisites

✅ AWS credentials configured (OIDC role)  
✅ PAT_TOKEN secret configured  
✅ GitHub CLI installed and authenticated  
✅ API Gateway exists (r8ukhidr1m)  
✅ All 4 services deployed

## Quick Test: Add v4

### Step 1: Trigger Workflow (1 minute)

```bash
gh workflow run add-new-version.yml \
  --repo rgcleanslage/iqq-project \
  -f new_version=v4 \
  -f status=planned
```

### Step 2: Monitor Progress (1-2 minutes)

```bash
# Watch workflow
gh run watch --repo rgcleanslage/iqq-project

# Or view in browser
gh run list --repo rgcleanslage/iqq-project --limit 1 --workflow=add-new-version.yml
```

### Step 3: Verify AWS Resources (30 seconds)

```bash
# Set API ID
API_ID="r8ukhidr1m"

# Check stage exists
aws apigateway get-stage \
  --rest-api-id "$API_ID" \
  --stage-name v4 \
  --region us-east-1

# Expected output: Stage details with stageName: v4
```

### Step 4: Check Lambda Permissions (30 seconds)

```bash
# Check one service (package)
aws lambda get-policy \
  --function-name iqq-package-service-dev \
  --qualifier v4 \
  --region us-east-1 2>/dev/null || echo "Alias not created yet (expected)"

# Note: This will fail until services are deployed with v4 alias
# That's expected and handled gracefully
```

### Step 5: Review Pull Requests (2 minutes)

```bash
# List all PRs
gh pr list --repo rgcleanslage/iqq-project
gh pr list --repo rgcleanslage/iqq-infrastructure
gh pr list --repo rgcleanslage/iqq-package-service
gh pr list --repo rgcleanslage/iqq-lender-service
gh pr list --repo rgcleanslage/iqq-product-service
gh pr list --repo rgcleanslage/iqq-document-service

# Expected: 6 PRs total, all with "add-version-v4" branch
```

### Step 6: Check Infrastructure PR (1 minute)

```bash
# View infrastructure PR
gh pr view 1 --repo rgcleanslage/iqq-infrastructure

# Look for:
# ✅ "Infrastructure Automatically Deployed"
# ✅ Stage URL in PR body
# ✅ Terraform code provided
```

### Step 7: Verify Stage URL (30 seconds)

```bash
# Get stage URL from workflow output
STAGE_URL="https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v4"

# Test (will fail until services deployed - that's expected)
curl -i "$STAGE_URL/package" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# Expected: 403 or 500 (no Lambda alias yet)
```

## What to Look For

### ✅ Success Indicators

1. **Workflow completes successfully** (all 14 jobs green)
2. **Stage exists in AWS** (aws apigateway get-stage succeeds)
3. **6 PRs created** (one per repository)
4. **5 release branches created** (release/v4 in all service repos)
5. **Infrastructure PR shows "Automatically Deployed"**
6. **Stage URL in PR body and workflow output**
7. **Terraform code generated in infrastructure PR**

### ❌ Failure Indicators

1. **deploy-infrastructure job fails**
2. **No stage in AWS**
3. **PRs missing**
4. **Error messages in workflow logs**
5. **No stage URL in output**

## Common Issues

### Issue: "API Gateway not found"
**Cause**: API Gateway doesn't exist or wrong name  
**Fix**: Verify API Gateway exists with name "iqq-api-dev"

### Issue: "No deployments found"
**Cause**: No deployments in API Gateway  
**Fix**: Deploy infrastructure first (one-time setup)

### Issue: Lambda permission fails
**Cause**: Lambda alias doesn't exist yet  
**Fix**: This is expected - deploy services first

### Issue: PAT_TOKEN error
**Cause**: Secret not configured or expired  
**Fix**: Create new PAT and add to secrets

## Full End-to-End Test

If you want to test the complete flow including service deployment:

### 1. Add Version (2 minutes)
```bash
gh workflow run add-new-version.yml \
  --repo rgcleanslage/iqq-project \
  -f new_version=v4 \
  -f status=planned
```

### 2. Merge PRs (5 minutes)
```bash
# Merge root PR
gh pr merge 1 --repo rgcleanslage/iqq-project --squash

# Merge service PRs
for SERVICE in package lender product document; do
  gh pr merge 1 --repo rgcleanslage/iqq-$SERVICE-service --squash
done

# Infrastructure PR - review but don't merge (optional)
```

### 3. Deploy Services (15-20 minutes)
```bash
gh workflow run deploy-version.yml \
  --repo rgcleanslage/iqq-project \
  -f version=v4 \
  -f services=all \
  -f environment=dev

# Wait for deployment
gh run watch --repo rgcleanslage/iqq-project
```

### 4. Test Endpoints (2 minutes)
```bash
# Set credentials
export TOKEN="your-token"
export API_KEY="your-api-key"

# Test all endpoints
for SERVICE in package lender product document; do
  echo "Testing $SERVICE..."
  curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v4/$SERVICE" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-api-key: $API_KEY" | grep -i "x-api-version"
done

# Expected: x-api-version: v4
```

## Alternative: Test with v99

If you want to test without affecting production versions:

```bash
# Use v99 for testing
gh workflow run add-new-version.yml \
  --repo rgcleanslage/iqq-project \
  -f new_version=v99 \
  -f status=planned

# After testing, clean up
aws apigateway delete-stage \
  --rest-api-id r8ukhidr1m \
  --stage-name v99 \
  --region us-east-1

# Close PRs without merging
for REPO in iqq-project iqq-infrastructure iqq-package-service iqq-lender-service iqq-product-service iqq-document-service; do
  gh pr close 1 --repo rgcleanslage/$REPO --delete-branch
done
```

## Verification Checklist

Use this checklist during testing:

- [ ] Workflow triggered successfully
- [ ] All 14 jobs completed (green checkmarks)
- [ ] API Gateway stage created in AWS
- [ ] Stage URL returned in workflow output
- [ ] 6 pull requests created
- [ ] 5 release branches created
- [ ] Infrastructure PR shows automated deployment
- [ ] Terraform code generated correctly
- [ ] Migration guide created
- [ ] Workflow dropdowns updated
- [ ] No errors in workflow logs
- [ ] Stage accessible via AWS CLI
- [ ] (Optional) Services deployed successfully
- [ ] (Optional) Endpoints return correct version headers

## Time Estimates

| Task | Time |
|------|------|
| Trigger workflow | 30 sec |
| Workflow execution | 1-2 min |
| Verify AWS resources | 1 min |
| Review PRs | 2-3 min |
| Merge PRs | 5 min |
| Deploy services | 15-20 min |
| Test endpoints | 2 min |
| **Total (quick test)** | **5-7 min** |
| **Total (full test)** | **25-35 min** |

## Success Criteria

The test is successful if:

1. ✅ Workflow completes without errors
2. ✅ API Gateway stage exists in AWS
3. ✅ Stage URL is accessible
4. ✅ All PRs created correctly
5. ✅ Infrastructure PR confirms automated deployment
6. ✅ Terraform code is valid and complete

## Next Steps After Testing

### If Test Passes ✅
1. Document results
2. Update version to stable
3. Announce to team
4. Use for production versions

### If Test Fails ❌
1. Check workflow logs
2. Verify AWS permissions
3. Check secrets configuration
4. Review error messages
5. Fix issues and retest

## Support

- **Documentation**: `docs/deployment/TASK_5_COMPLETE.md`
- **Workflow Guide**: `docs/deployment/ADD_NEW_VERSION_WORKFLOW_GUIDE.md`
- **Workflow File**: `.github/workflows/add-new-version.yml`

---

**Ready to test!** Start with Step 1 above.

