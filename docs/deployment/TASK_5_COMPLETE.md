# Task 5 Complete: Create Release Branches

**Date**: February 18, 2026  
**Status**: ✅ Complete

## Overview

Successfully created release branches for v1 and v2 across all service repositories and infrastructure repository.

## What Was Accomplished

### Release Branches Created

Created `release/v1` and `release/v2` branches in:

1. ✅ **iqq-package-service**
   - release/v1: https://github.com/rgcleanslage/iqq-package-service/tree/release/v1
   - release/v2: https://github.com/rgcleanslage/iqq-package-service/tree/release/v2

2. ✅ **iqq-lender-service**
   - release/v1: https://github.com/rgcleanslage/iqq-lender-service/tree/release/v1
   - release/v2: https://github.com/rgcleanslage/iqq-lender-service/tree/release/v2

3. ✅ **iqq-product-service**
   - release/v1: https://github.com/rgcleanslage/iqq-product-service/tree/release/v1
   - release/v2: https://github.com/rgcleanslage/iqq-product-service/tree/release/v2

4. ✅ **iqq-document-service**
   - release/v1: https://github.com/rgcleanslage/iqq-document-service/tree/release/v1
   - release/v2: https://github.com/rgcleanslage/iqq-document-service/tree/release/v2

5. ✅ **iqq-infrastructure**
   - release/v1: https://github.com/rgcleanslage/iqq-infrastructure/tree/release/v1
   - release/v2: https://github.com/rgcleanslage/iqq-infrastructure/tree/release/v2

### Automation Script Created

Created `scripts/create-release-branches-auto.sh` for automated branch creation:

```bash
./scripts/create-release-branches-auto.sh v1
./scripts/create-release-branches-auto.sh v2
```

Features:
- Non-interactive (no prompts)
- Handles existing branches automatically
- Creates branches from main
- Pushes to remote automatically
- Provides detailed progress output
- Summary report at completion

## Branch Strategy

### Purpose

Release branches allow:
- Independent version development
- Hotfixes to specific versions
- Version-specific code changes
- Parallel version maintenance

### Naming Convention

```
release/v1
release/v2
release/v3
...
```

### Workflow

1. **Development**: Work on `main` branch
2. **Release**: Create `release/vX` branch from main
3. **Deploy**: Deploy from release branch to Lambda alias
4. **Hotfix**: Make fixes directly to release branch
5. **Backport**: Cherry-pick fixes to other release branches if needed

## Verification

### Check Branches Locally

```bash
# Check all repositories
for repo in iqq-package-service iqq-lender-service iqq-product-service iqq-document-service iqq-infrastructure; do
  echo "=== $repo ==="
  git -C "$repo" branch -a | grep release
  echo ""
done
```

### Check Branches on GitHub

Visit each repository and verify branches exist:
- https://github.com/rgcleanslage/iqq-package-service/branches
- https://github.com/rgcleanslage/iqq-lender-service/branches
- https://github.com/rgcleanslage/iqq-product-service/branches
- https://github.com/rgcleanslage/iqq-document-service/branches
- https://github.com/rgcleanslage/iqq-infrastructure/branches

## Next Steps

With release branches created, proceed to:

### Task 6: Deploy Initial Versions

1. **Deploy v1 to Lambda**
   - Use GitHub Actions "Deploy API Version" workflow
   - Version: v1
   - Services: all
   - Creates Lambda aliases: v1

2. **Deploy v2 to Lambda**
   - Use GitHub Actions "Deploy API Version" workflow
   - Version: v2
   - Services: all
   - Creates Lambda aliases: v2

3. **Apply Terraform Changes**
   - Already completed in Task 2
   - v1 and v2 stages exist in API Gateway
   - Lambda permissions configured

### Task 7: Verify Versioned Endpoints

After deployment, test:
- v1 endpoints: `/v1/package`, `/v1/lender`, `/v1/product`, `/v1/document`
- v2 endpoints: `/v2/package`, `/v2/lender`, `/v2/product`, `/v2/document`
- Version headers in responses
- Concurrent access to both versions

## Branch Management Best Practices

### Creating New Version Branches

Use the automated script:
```bash
./scripts/create-release-branches-auto.sh v3
```

Or use the "Add New API Version" GitHub Actions workflow.

### Updating Release Branches

```bash
# Switch to release branch
git checkout release/v1

# Make changes
git add .
git commit -m "fix: description"

# Push to remote
git push origin release/v1
```

### Hotfixes

For urgent fixes to a specific version:

```bash
# Create hotfix branch from release branch
git checkout release/v1
git checkout -b hotfix/v1-critical-fix

# Make fix
git add .
git commit -m "hotfix: critical issue"

# Merge back to release branch
git checkout release/v1
git merge hotfix/v1-critical-fix

# Push
git push origin release/v1

# Deploy using GitHub Actions
# Workflow: Deploy API Version
# Version: v1
# Services: affected-service
```

### Backporting Fixes

To apply a fix to multiple versions:

```bash
# Get commit hash from one release branch
git log release/v2 --oneline | head -5

# Cherry-pick to another release branch
git checkout release/v1
git cherry-pick <commit-hash>
git push origin release/v1
```

## Files Created/Modified

### New Files
- `scripts/create-release-branches-auto.sh` - Automated branch creation script
- `docs/deployment/TASK_5_COMPLETE.md` - This document

### Modified Files
- `.kiro/specs/api-versioning/tasks.md` - Marked Task 5 as complete

## Summary

Task 5 is complete. All release branches (v1 and v2) have been created in all 5 repositories and pushed to GitHub. The automated script is available for creating future version branches.

Ready to proceed with Task 6: Deploy Initial Versions.

---

**Completed**: February 18, 2026  
**Repositories**: 5 (4 services + 1 infrastructure)  
**Branches Created**: 10 (v1 and v2 in each repository)  
**Script**: `scripts/create-release-branches-auto.sh`
