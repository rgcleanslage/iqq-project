# Release Branch Strategy

**Last Updated**: February 19, 2026  
**Status**: Partially Implemented

## Overview

The iQQ API uses a release branch strategy to manage multiple API versions independently. Each API version (v1, v2, v3, etc.) has its own release branch in each service repository, allowing for:

- Independent version development
- Version-specific hotfixes
- Parallel maintenance of multiple versions
- Safe backporting of fixes

## Current Implementation Status

### ✅ What's Implemented

1. **Manual Release Branch Creation**
   - Script: `scripts/create-release-branches.sh` (interactive)
   - Script: `scripts/create-release-branches-auto.sh` (automated)
   - Existing branches: `release/v1` and `release/v2` in all repositories

2. **Deployment from Main Branch**
   - GitHub Actions workflows deploy from `main` branch
   - Lambda aliases (v1, v2) point to versions deployed from main
   - Works for current v1 and v2 setup

### ⚠️ What's Missing

1. **Automated Release Branch Creation in Workflows**
   - "Add New Version" workflow doesn't create release branches
   - Must be created manually using scripts

2. **Deployment from Release Branches**
   - Workflows currently deploy from `main` branch
   - Should deploy from `release/vX` branches for production versions

3. **Branch Protection Rules**
   - No automated branch protection setup
   - Should require PR reviews for release branches

## Branch Structure

### Naming Convention

```
main                    # Development branch (latest code)
release/v1             # Production code for v1
release/v2             # Production code for v2
release/v3             # Production code for v3 (future)
```

### Repository Coverage

Release branches exist in:
- ✅ iqq-package-service
- ✅ iqq-lender-service
- ✅ iqq-product-service
- ✅ iqq-document-service
- ✅ iqq-infrastructure

## How Release Branches Are Created

### Current Process (Manual)

#### Option 1: Interactive Script

```bash
cd iqq-project
./scripts/create-release-branches.sh v3
```

**Features**:
- Prompts before overwriting existing branches
- Interactive confirmation
- Good for manual testing

#### Option 2: Automated Script

```bash
cd iqq-project
./scripts/create-release-branches-auto.sh v3
```

**Features**:
- No prompts (fully automated)
- Handles existing branches automatically
- Good for CI/CD integration

**What the script does**:
1. Validates version format (v1, v2, v3, etc.)
2. For each repository:
   - Checks if directory exists
   - Fetches latest changes from remote
   - Checks if branch already exists (local or remote)
   - If exists: Checks out existing branch
   - If not exists: Creates from main and pushes to remote
3. Provides summary report

### Repositories Processed

The script creates branches in:
1. iqq-package-service
2. iqq-lender-service
3. iqq-product-service
4. iqq-document-service
5. iqq-infrastructure

## Recommended Workflow Integration

### When Adding a New Version

The "Add New Version" workflow should be enhanced to include release branch creation:

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
        
        # Check if branch exists
        if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
          echo "Branch $BRANCH_NAME already exists"
          exit 0
        fi
        
        # Create and push branch
        git checkout -b "$BRANCH_NAME"
        git push -u origin "$BRANCH_NAME"
        
        echo "✅ Created branch $BRANCH_NAME in ${{ matrix.repo }}"
```

### When Deploying a Version

Deployment workflows should be updated to deploy from release branches:

**Current** (deploys from main):
```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

**Recommended** (deploys from release branch):
```yaml
- name: Checkout code
  uses: actions/checkout@v4
  with:
    ref: release/${{ github.event.inputs.version }}
```

## Branch Lifecycle

### 1. Planned Status

**Branch**: Not created yet  
**Code**: N/A  
**Action**: Version added to config only

```bash
# No branch creation needed
# Just update config/version-policy.json
```

### 2. Alpha Status

**Branch**: Created from main  
**Code**: Latest development code  
**Action**: Create release branch

```bash
./scripts/create-release-branches-auto.sh v3
```

### 3. Beta Status

**Branch**: Exists, receiving updates  
**Code**: Feature-complete, being tested  
**Action**: Continue development on release branch

```bash
git checkout release/v3
# Make changes
git commit -m "feat: new feature"
git push origin release/v3
```

### 4. Stable Status

**Branch**: Frozen for production  
**Code**: Production-ready  
**Action**: Only hotfixes allowed

```bash
# Hotfixes only via PR
git checkout release/v3
git checkout -b hotfix/v3-critical-fix
# Make fix
# Create PR to release/v3
```

### 5. Deprecated Status

**Branch**: Maintained for existing users  
**Code**: No new features, only critical fixes  
**Action**: Minimal maintenance

```bash
# Critical fixes only
# Encourage migration to newer version
```

### 6. Sunset Status

**Branch**: Archived  
**Code**: No longer deployed  
**Action**: Branch remains for history

```bash
# Branch kept for reference
# No longer deployed
# Lambda alias removed
```

## Hotfix Workflow

### Scenario: Critical bug in v1 production

```bash
# 1. Create hotfix branch from release branch
cd iqq-package-service
git checkout release/v1
git pull origin release/v1
git checkout -b hotfix/v1-critical-bug

# 2. Make the fix
# Edit files...
git add .
git commit -m "hotfix: fix critical bug in v1"

# 3. Push and create PR
git push origin hotfix/v1-critical-bug
# Create PR: hotfix/v1-critical-bug → release/v1

# 4. After PR is merged, deploy
# Use GitHub Actions: Deploy API Version
# Version: v1
# Services: package (or affected service)

# 5. (Optional) Backport to other versions
git checkout release/v2
git cherry-pick <commit-hash>
git push origin release/v2
```

## Backporting Fixes

### Scenario: Fix in v2 needs to be applied to v1

```bash
# 1. Find the commit in v2
cd iqq-package-service
git checkout release/v2
git log --oneline | head -10
# Note the commit hash

# 2. Cherry-pick to v1
git checkout release/v1
git cherry-pick <commit-hash>

# 3. Resolve conflicts if any
# Edit files if needed
git add .
git cherry-pick --continue

# 4. Push
git push origin release/v1

# 5. Deploy v1
# Use GitHub Actions: Deploy API Version
# Version: v1
# Services: package
```

## Branch Protection Rules

### Recommended Settings

For each `release/*` branch:

1. **Require pull request reviews**
   - Required approvals: 1
   - Dismiss stale reviews: Yes

2. **Require status checks**
   - Require branches to be up to date: Yes
   - Required checks:
     - Tests
     - Build
     - Lint

3. **Require conversation resolution**
   - Yes

4. **Do not allow bypassing**
   - Enforce for administrators: Yes

5. **Restrict who can push**
   - Only allow: Maintainers, Admins

### Setting Up Protection Rules

```bash
# Using GitHub CLI
gh api repos/rgcleanslage/iqq-package-service/branches/release/v1/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["test","build"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}'
```

Or via GitHub UI:
1. Go to repository → Settings → Branches
2. Add branch protection rule
3. Branch name pattern: `release/*`
4. Configure protection settings

## Comparison: Current vs. Recommended

### Current Approach

```
main branch
    ↓
  Deploy
    ↓
Lambda v1 alias → version 4
Lambda v2 alias → $LATEST
```

**Pros**:
- Simple
- Works for current setup
- Easy to understand

**Cons**:
- v1 and v2 share same codebase
- Can't have version-specific code
- Hotfixes affect all versions
- No independent version maintenance

### Recommended Approach

```
release/v1 branch → Deploy → Lambda v1 alias → version 4
release/v2 branch → Deploy → Lambda v2 alias → version 5
main branch → Development
```

**Pros**:
- Independent version maintenance
- Version-specific code possible
- Hotfixes isolated to specific versions
- Safer production deployments
- Better version control

**Cons**:
- More complex
- Requires branch management
- Need to backport fixes manually

## Migration Path

### Phase 1: Create Release Branches (✅ Complete)

```bash
./scripts/create-release-branches-auto.sh v1
./scripts/create-release-branches-auto.sh v2
```

Status: ✅ Done (February 18, 2026)

### Phase 2: Update Workflows (⚠️ Pending)

1. **Update "Add New Version" workflow**
   - Add release branch creation step
   - Use matrix strategy for parallel creation

2. **Update "Deploy API Version" workflow**
   - Deploy from release branches instead of main
   - Add branch validation

3. **Update service deployment workflows**
   - Accept branch parameter
   - Default to release/{version}

### Phase 3: Set Branch Protection (⚠️ Pending)

```bash
# For each repository and each release branch
# Set up protection rules via GitHub UI or API
```

### Phase 4: Update Documentation (⚠️ Pending)

- Update deployment guides
- Update contribution guidelines
- Add branch strategy to README

## Example: Complete Version Lifecycle

### Adding v3

```bash
# 1. Run "Add New Version" workflow
# Inputs: version=v3, status=planned

# 2. Merge all PRs (6 total)

# 3. Create release branches (manual for now)
./scripts/create-release-branches-auto.sh v3

# 4. Update infrastructure (manual)
# Add v3 stage to Terraform
terraform apply

# 5. Deploy services from release/v3 branch
# Use "Deploy API Version" workflow
# Version: v3, Services: all

# 6. Test v3 endpoints
curl https://api.example.com/v3/package

# 7. Update status to alpha
# Use "Deprecate API Version" workflow (or manual update)

# 8. Continue development on release/v3
git checkout release/v3
# Make changes
git push origin release/v3

# 9. When ready, update status to stable
```

### Hotfix to v1

```bash
# 1. Create hotfix branch
git checkout release/v1
git checkout -b hotfix/v1-security-fix

# 2. Make fix
# Edit files
git commit -m "hotfix: security vulnerability"

# 3. Create PR to release/v1
gh pr create --base release/v1

# 4. After merge, deploy
# Use "Deploy API Version" workflow
# Version: v1, Services: affected-service

# 5. Verify fix
curl https://api.example.com/v1/package
```

## Tools and Scripts

### Available Scripts

| Script | Purpose | Interactive | Location |
|--------|---------|-------------|----------|
| `create-release-branches.sh` | Create release branches | Yes | `scripts/` |
| `create-release-branches-auto.sh` | Create release branches | No | `scripts/` |

### GitHub Actions Workflows

| Workflow | Creates Branches | Deploys From |
|----------|-----------------|--------------|
| Add New Version | ❌ No (should be added) | N/A |
| Deploy API Version | ❌ No | main (should be release/vX) |
| Service Deploy | ❌ No | main (should be release/vX) |

## Best Practices

### 1. Branch Creation

- ✅ Create release branches when version reaches alpha status
- ✅ Use automated script for consistency
- ✅ Create branches in all repositories simultaneously
- ❌ Don't create branches for "planned" status

### 2. Development

- ✅ Develop new features on main branch
- ✅ Create release branch when ready for testing
- ✅ Make version-specific changes on release branches
- ❌ Don't merge release branches back to main

### 3. Hotfixes

- ✅ Create hotfix branch from release branch
- ✅ Use PR process for hotfixes
- ✅ Deploy immediately after merge
- ✅ Consider backporting to other versions
- ❌ Don't commit directly to release branches

### 4. Backporting

- ✅ Use cherry-pick for selective backporting
- ✅ Test thoroughly after backporting
- ✅ Document which versions received the fix
- ❌ Don't backport breaking changes

### 5. Branch Protection

- ✅ Require PR reviews for release branches
- ✅ Require passing tests
- ✅ Enforce for administrators
- ❌ Don't allow force pushes

## Troubleshooting

### Issue: Branch already exists

```bash
# If branch exists locally but not on remote
git branch -D release/v3
./scripts/create-release-branches-auto.sh v3

# If branch exists on remote
# Script will checkout existing branch automatically
```

### Issue: Can't push to remote

```bash
# Check authentication
gh auth status

# Check remote URL
git remote -v

# Try manual push
git push -u origin release/v3
```

### Issue: Merge conflicts during cherry-pick

```bash
# Resolve conflicts
git status
# Edit conflicting files
git add .
git cherry-pick --continue

# Or abort
git cherry-pick --abort
```

### Issue: Wrong code deployed

```bash
# Check which branch was deployed
git log --oneline -5

# Redeploy from correct branch
# Use GitHub Actions with correct version
```

## Future Enhancements

### 1. Automated Branch Creation in Workflows

Add to "Add New Version" workflow:
- Create release branches automatically
- Set up branch protection rules
- Notify team of new branches

### 2. Deploy from Release Branches

Update all deployment workflows:
- Deploy from `release/{version}` instead of `main`
- Validate branch exists before deployment
- Add branch parameter to workflows

### 3. Branch Synchronization

Create workflow to:
- Sync changes between release branches
- Automated backporting of approved fixes
- Conflict detection and notification

### 4. Branch Cleanup

Create workflow to:
- Archive sunset version branches
- Clean up old hotfix branches
- Maintain branch history

## Summary

**Current State**:
- ✅ Release branches exist for v1 and v2
- ✅ Scripts available for creating new branches
- ⚠️ Workflows deploy from main (not release branches)
- ⚠️ No automated branch creation in workflows

**Recommended Next Steps**:
1. Update "Add New Version" workflow to create release branches
2. Update deployment workflows to deploy from release branches
3. Set up branch protection rules
4. Document the process for the team

**Time Estimate**:
- Workflow updates: 2-3 hours
- Branch protection setup: 1 hour
- Testing: 1-2 hours
- Documentation: 1 hour
- **Total**: 5-7 hours

---

**Last Updated**: February 19, 2026  
**Status**: Documentation complete, implementation partially complete  
**Next Action**: Update workflows to integrate release branch strategy
