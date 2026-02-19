# GitHub Actions Workflow Update Recommendations

**Date**: February 19, 2026  
**Status**: Analysis Complete

## Executive Summary

After reviewing all GitHub Actions workflows, several updates are recommended to improve functionality, consistency, and alignment with the release branch strategy. Most workflows are functional but have minor issues that should be addressed.

## Workflows Analyzed

1. ✅ `add-new-version.yml` - Fixed (Linux compatibility)
2. ⚠️ `deploy-version.yml` - Needs updates
3. ⚠️ `deprecate-version.yml` - Needs updates
4. ⚠️ `sunset-version.yml` - Needs updates
5. ⚠️ `generate-migration-guide.yml` - Needs updates
6. ✅ Service deployment workflows (4 repos) - Working

## Critical Issues

### 1. macOS-Specific sed Commands

**Affected Workflows**:
- ❌ `generate-migration-guide.yml` (line ~380)

**Issue**:
```yaml
sed -i '' "s/\${FROM_VERSION}/${FROM_VERSION}/g" ...
```

The `sed -i ''` syntax is macOS-specific and will fail on Ubuntu (GitHub Actions).

**Fix**:
```yaml
sed -i "s/\${FROM_VERSION}/${FROM_VERSION}/g" ...
```

**Status**: ⚠️ Needs fixing

### 2. Missing Release Branch Integration

**Affected Workflows**:
- `add-new-version.yml` - Doesn't create release branches
- `deploy-version.yml` - Deploys from main instead of release branches
- Service workflows - Deploy from main instead of release branches

**Issue**: Workflows don't leverage the release branch strategy documented in the system.

**Impact**: 
- Can't maintain version-specific code
- Hotfixes affect all versions
- No independent version maintenance

**Status**: ⚠️ Enhancement needed

### 3. Hardcoded Version Lists

**Affected Workflows**:
- `deprecate-version.yml`
- `sunset-version.yml`

**Issue**:
```yaml
options:
  - v1
  - v2
```

Version lists are hardcoded and must be manually updated when adding new versions.

**Fix**: The `add-new-version.yml` workflow updates these, but it uses awk which may not work correctly for YAML.

**Status**: ⚠️ Needs verification

## Detailed Recommendations

### Priority 1: Critical Fixes (Do Immediately)

#### 1.1 Fix sed Commands in generate-migration-guide.yml

**File**: `.github/workflows/generate-migration-guide.yml`  
**Lines**: ~380-382

**Current**:
```yaml
sed -i '' "s/\${FROM_VERSION}/${FROM_VERSION}/g" docs/api/migrations/MIGRATION_${FROM_VERSION}_TO_${TO_VERSION}.md
sed -i '' "s/\${TO_VERSION}/${TO_VERSION}/g" docs/api/migrations/MIGRATION_${FROM_VERSION}_TO_${TO_VERSION}.md
sed -i '' "s/\${DATE}/${DATE}/g" docs/api/migrations/MIGRATION_${FROM_VERSION}_TO_${TO_VERSION}.md
```

**Fixed**:
```yaml
sed -i "s/\${FROM_VERSION}/${FROM_VERSION}/g" docs/api/migrations/MIGRATION_${FROM_VERSION}_TO_${TO_VERSION}.md
sed -i "s/\${TO_VERSION}/${TO_VERSION}/g" docs/api/migrations/MIGRATION_${FROM_VERSION}_TO_${TO_VERSION}.md
sed -i "s/\${DATE}/${DATE}/g" docs/api/migrations/MIGRATION_${FROM_VERSION}_TO_${TO_VERSION}.md
```

**Effort**: 5 minutes  
**Risk**: Low

### Priority 2: Important Enhancements (Do Soon)

#### 2.1 Add Release Branch Creation to add-new-version.yml

**File**: `.github/workflows/add-new-version.yml`  
**Location**: After `update-service-configs` job

**Add New Job**:
```yaml
create-release-branches:
  name: Create Release Branches
  needs: validate-version
  runs-on: ubuntu-latest
  strategy:
    matrix:
      repo: [iqq-package-service, iqq-lender-service, iqq-product-service, iqq-document-service, iqq-infrastructure]
  steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      with:
        repository: ${{ env.GITHUB_ORG }}/${{ matrix.repo }}
        token: ${{ secrets.PAT_TOKEN }}
        fetch-depth: 0
    
    - name: Create release branch
      run: |
        VERSION="${{ needs.validate-version.outputs.version }}"
        BRANCH_NAME="release/$VERSION"
        
        echo "🌿 Creating release branch: $BRANCH_NAME"
        
        # Check if branch already exists on remote
        if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
          echo "ℹ️  Branch $BRANCH_NAME already exists"
          exit 0
        fi
        
        # Create and push branch from main
        git checkout main
        git pull origin main
        git checkout -b "$BRANCH_NAME"
        git push -u origin "$BRANCH_NAME"
        
        echo "✅ Created branch $BRANCH_NAME in ${{ matrix.repo }}"
```

**Benefits**:
- Automates release branch creation
- Ensures consistency across repositories
- Reduces manual steps

**Effort**: 30 minutes  
**Risk**: Low

#### 2.2 Update Deployment Workflows to Use Release Branches

**Affected Files**:
- `.github/workflows/deploy-version.yml`
- `iqq-*-service/.github/workflows/deploy.yml` (4 files)

**Current** (deploys from main):
```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

**Updated** (deploys from release branch):
```yaml
- name: Checkout code
  uses: actions/checkout@v4
  with:
    ref: release/${{ github.event.inputs.version }}
```

**Benefits**:
- Enables version-specific code
- Allows independent version maintenance
- Safer production deployments

**Effort**: 1 hour (5 files)  
**Risk**: Medium (requires testing)

#### 2.3 Add Branch Validation

**Add to all deployment workflows**:

```yaml
- name: Validate release branch
  run: |
    VERSION="${{ github.event.inputs.version }}"
    BRANCH="release/$VERSION"
    
    # Check if branch exists
    if ! git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
      echo "❌ Release branch $BRANCH does not exist"
      echo "   Please create it first using:"
      echo "   ./scripts/create-release-branches-auto.sh $VERSION"
      exit 1
    fi
    
    echo "✅ Release branch $BRANCH exists"
```

**Benefits**:
- Prevents deployment errors
- Provides clear error messages
- Guides users to correct action

**Effort**: 30 minutes  
**Risk**: Low

### Priority 3: Nice-to-Have Improvements (Do Later)

#### 3.1 Add Workflow Status Badges

**File**: `README.md`

**Add**:
```markdown
## Workflow Status

[![Add New Version](https://github.com/rgcleanslage/iqq-project/actions/workflows/add-new-version.yml/badge.svg)](https://github.com/rgcleanslage/iqq-project/actions/workflows/add-new-version.yml)
[![Deploy Version](https://github.com/rgcleanslage/iqq-project/actions/workflows/deploy-version.yml/badge.svg)](https://github.com/rgcleanslage/iqq-project/actions/workflows/deploy-version.yml)
[![Deprecate Version](https://github.com/rgcleanslage/iqq-project/actions/workflows/deprecate-version.yml/badge.svg)](https://github.com/rgcleanslage/iqq-project/actions/workflows/deprecate-version.yml)
[![Sunset Version](https://github.com/rgcleanslage/iqq-project/actions/workflows/sunset-version.yml/badge.svg)](https://github.com/rgcleanslage/iqq-project/actions/workflows/sunset-version.yml)
```

**Benefits**:
- Quick visual status check
- Professional appearance
- Easy monitoring

**Effort**: 5 minutes  
**Risk**: None

#### 3.2 Add Slack/Email Notifications

**Add to all workflows**:

```yaml
- name: Notify team
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: |
      Workflow: ${{ github.workflow }}
      Version: ${{ github.event.inputs.version }}
      Status: ${{ job.status }}
      Triggered by: ${{ github.actor }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

**Benefits**:
- Team awareness
- Faster incident response
- Audit trail

**Effort**: 1 hour  
**Risk**: Low

#### 3.3 Add Workflow Concurrency Control

**Add to all workflows**:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.inputs.version }}
  cancel-in-progress: false
```

**Benefits**:
- Prevents concurrent deployments of same version
- Avoids race conditions
- Clearer workflow status

**Effort**: 15 minutes  
**Risk**: Low

#### 3.4 Improve Error Handling

**Add retry logic for AWS operations**:

```yaml
- name: Deploy with retry
  uses: nick-invision/retry@v2
  with:
    timeout_minutes: 10
    max_attempts: 3
    retry_wait_seconds: 30
    command: |
      sam deploy \
        --stack-name "$STACK_NAME" \
        --s3-bucket "${{ secrets.SAM_DEPLOYMENT_BUCKET }}" \
        --capabilities CAPABILITY_IAM \
        --no-fail-on-empty-changeset
```

**Benefits**:
- Handles transient failures
- Reduces manual intervention
- More reliable deployments

**Effort**: 1 hour  
**Risk**: Low

### Priority 4: Documentation Updates

#### 4.1 Update Workflow README

**File**: `.github/workflows/README.md`

**Add**:
- Release branch strategy integration
- Workflow dependencies diagram
- Troubleshooting section
- Common error messages and solutions

**Effort**: 1 hour  
**Risk**: None

#### 4.2 Create Workflow Runbook

**New File**: `docs/deployment/WORKFLOW_RUNBOOK.md`

**Include**:
- Step-by-step procedures for each workflow
- Prerequisites checklist
- Verification steps
- Rollback procedures
- Emergency contacts

**Effort**: 2 hours  
**Risk**: None

## Workflow-Specific Recommendations

### add-new-version.yml ✅

**Status**: Fixed (February 19, 2026)

**Recent Fixes**:
- ✅ Fixed sed commands for Linux compatibility
- ✅ Replaced sed append with awk

**Remaining Issues**:
- ⚠️ Doesn't create release branches (Priority 2.1)
- ⚠️ No branch protection setup

**Recommended Additions**:
1. Add release branch creation job
2. Add branch protection setup
3. Add validation that PAT_TOKEN has correct permissions

### deploy-version.yml ⚠️

**Status**: Functional but needs enhancement

**Issues**:
- Deploys from main instead of release branches
- No branch validation
- Missing AWS_ROLE_ARN secret in root repo (optional)

**Recommended Updates**:
1. Deploy from release branches (Priority 2.2)
2. Add branch validation (Priority 2.3)
3. Add concurrency control (Priority 3.3)
4. Add retry logic (Priority 3.4)

**Effort**: 2 hours  
**Risk**: Medium

### deprecate-version.yml ⚠️

**Status**: Functional but needs enhancement

**Issues**:
- Hardcoded version list
- No release branch awareness
- Deploys updated config from main

**Recommended Updates**:
1. Deploy from release branches
2. Add branch validation
3. Verify version list updates work correctly

**Effort**: 1 hour  
**Risk**: Low

### sunset-version.yml ⚠️

**Status**: Functional but needs enhancement

**Issues**:
- Hardcoded version list
- No release branch cleanup
- No branch archival

**Recommended Updates**:
1. Add release branch archival step
2. Add branch protection removal
3. Add verification that no active deployments exist

**Effort**: 1 hour  
**Risk**: Low

### generate-migration-guide.yml ❌

**Status**: Has critical bug

**Issues**:
- ❌ macOS-specific sed commands (Priority 1.1)
- Compares main branch instead of release branches
- Limited code analysis

**Recommended Updates**:
1. Fix sed commands (Priority 1.1) - CRITICAL
2. Compare release branches instead of main
3. Enhance code analysis (AST parsing, breaking change detection)
4. Add automated testing of migration steps

**Effort**: 2 hours  
**Risk**: Medium

### Service Deployment Workflows ✅

**Status**: Working (tested February 19, 2026)

**Issues**:
- Deploy from main instead of release branches
- No branch parameter

**Recommended Updates**:
1. Add branch parameter (default to release/{version})
2. Add branch validation
3. Add concurrency control

**Effort**: 1 hour (4 files)  
**Risk**: Low

## Implementation Plan

### Phase 1: Critical Fixes (Week 1)

**Tasks**:
1. Fix sed commands in generate-migration-guide.yml
2. Test all workflows with current setup
3. Document any other critical issues

**Effort**: 4 hours  
**Risk**: Low

### Phase 2: Release Branch Integration (Week 2)

**Tasks**:
1. Add release branch creation to add-new-version.yml
2. Update deploy-version.yml to use release branches
3. Update service workflows to use release branches
4. Add branch validation to all workflows
5. Test complete workflow with new version

**Effort**: 8 hours  
**Risk**: Medium  
**Testing Required**: Yes

### Phase 3: Enhancements (Week 3)

**Tasks**:
1. Add concurrency control
2. Add retry logic
3. Add notifications
4. Add workflow status badges
5. Update documentation

**Effort**: 6 hours  
**Risk**: Low

### Phase 4: Documentation (Week 4)

**Tasks**:
1. Update workflow README
2. Create workflow runbook
3. Update deployment guides
4. Create troubleshooting guide

**Effort**: 4 hours  
**Risk**: None

**Total Effort**: ~22 hours (3 days)

## Testing Strategy

### Unit Testing

For each workflow update:
1. Test with dry-run mode (if available)
2. Test with non-production version (e.g., v99)
3. Verify all jobs complete successfully
4. Check all artifacts are created

### Integration Testing

1. Test complete version lifecycle:
   - Add new version (v3)
   - Deploy v3
   - Deprecate v2
   - Sunset v1
2. Verify all repositories updated correctly
3. Verify all AWS resources created/updated
4. Test rollback procedures

### Regression Testing

1. Test existing v1 and v2 deployments still work
2. Verify no breaking changes to current setup
3. Test hotfix workflow on existing versions

## Rollback Plan

If workflow updates cause issues:

### Immediate Rollback

```bash
# Revert workflow files
git revert <commit-hash>
git push

# Or restore from backup
git checkout <previous-commit> -- .github/workflows/
git commit -m "rollback: restore previous workflows"
git push
```

### Gradual Rollback

1. Identify problematic workflow
2. Revert only that workflow
3. Keep other improvements
4. Document issue for future fix

## Success Criteria

### Phase 1 (Critical Fixes)
- ✅ All workflows run without errors
- ✅ No macOS-specific commands
- ✅ All sed/awk commands work on Ubuntu

### Phase 2 (Release Branch Integration)
- ✅ Release branches created automatically
- ✅ Deployments use release branches
- ✅ Branch validation prevents errors
- ✅ Complete v3 lifecycle test passes

### Phase 3 (Enhancements)
- ✅ Concurrent deployments prevented
- ✅ Transient failures handled automatically
- ✅ Team notified of workflow status
- ✅ Workflow badges visible

### Phase 4 (Documentation)
- ✅ All workflows documented
- ✅ Runbook created and tested
- ✅ Troubleshooting guide complete
- ✅ Team trained on new workflows

## Risk Assessment

### Low Risk Updates
- sed command fixes
- Documentation updates
- Status badges
- Concurrency control

### Medium Risk Updates
- Release branch integration
- Deployment workflow changes
- Branch validation

### High Risk Updates
- None identified

## Monitoring and Alerts

### Metrics to Track

1. **Workflow Success Rate**
   - Target: >95%
   - Alert if: <90%

2. **Workflow Duration**
   - Target: <20 minutes
   - Alert if: >30 minutes

3. **Deployment Frequency**
   - Track: Deployments per week
   - Monitor: Trends over time

4. **Failure Reasons**
   - Track: Common failure patterns
   - Action: Address top 3 causes

### Monitoring Tools

- GitHub Actions dashboard
- CloudWatch metrics
- Custom dashboard (optional)

## Conclusion

Most workflows are functional but need enhancements to fully leverage the release branch strategy. The critical fix (sed commands) should be applied immediately, followed by release branch integration in the next sprint.

**Immediate Action Required**:
1. Fix sed commands in generate-migration-guide.yml
2. Test all workflows
3. Plan Phase 2 implementation

**Estimated Total Effort**: 22 hours (3 days)  
**Recommended Timeline**: 4 weeks  
**Risk Level**: Low to Medium

---

**Last Updated**: February 19, 2026  
**Next Review**: After Phase 2 completion  
**Owner**: DevOps Team
