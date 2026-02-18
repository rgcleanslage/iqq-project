# API Versioning Setup Guide

## Overview

This guide documents the setup of API versioning infrastructure for the iQQ Insurance Quoting Platform. The implementation uses stage-based versioning with API Gateway stages (v1, v2) and centralized orchestration from the root repository.

## Task 1: Version Control Structure ✅

**Status**: Complete  
**Date**: February 18, 2026

### What Was Created

#### 1. Centralized Version Policy Configuration

**File**: `config/version-policy.json`

This JSON file serves as the single source of truth for API versioning across all services:

```json
{
  "currentVersion": "v1",
  "supportedVersions": ["v1", "v2"],
  "versions": {
    "v1": {
      "status": "stable",
      "lambdaAlias": "v1",
      "description": "Initial stable version"
    },
    "v2": {
      "status": "planned",
      "lambdaAlias": "v2",
      "description": "Next version with enhanced features"
    }
  },
  "services": {
    "package": {
      "repository": "https://github.com/rgcleanslage/iqq-package-service",
      "lambdaFunction": "iqq-package-service-dev"
    },
    // ... other services
  }
}
```

**Purpose**:
- Define supported API versions
- Track version lifecycle (planned → stable → deprecated → sunset)
- Map services to their repositories and Lambda functions
- Configure deprecation policies
- Store version metadata (release dates, breaking changes, migration guides)

#### 2. Release Branch Creation Script

**File**: `scripts/create-release-branches.sh`

Automated script to create release branches across all service repositories:

```bash
./scripts/create-release-branches.sh v1
./scripts/create-release-branches.sh v2
```

**Features**:
- Creates `release/v1` and `release/v2` branches in all service repos
- Handles existing branches gracefully
- Pushes branches to remote automatically
- Provides detailed progress and error reporting
- Works with separate service repositories

**Repositories Affected**:
- iqq-package-service
- iqq-lender-service
- iqq-product-service
- iqq-document-service
- iqq-infrastructure

#### 3. Configuration Documentation

**File**: `config/README.md`

Comprehensive documentation covering:
- Version policy schema and usage
- Version lifecycle management
- Integration with GitHub Actions
- Best practices for version management
- Examples of common operations

### Repository Structure

Since services are in separate repositories, the structure is:

```
iqq-project/ (this repository - documentation and orchestration)
├── config/
│   ├── version-policy.json       # Central version configuration
│   └── README.md                 # Configuration documentation
├── scripts/
│   └── create-release-branches.sh # Branch creation automation
└── .github/workflows/
    └── (future: orchestration workflows)

iqq-package-service/ (separate repository)
├── release/v1 branch
└── release/v2 branch

iqq-lender-service/ (separate repository)
├── release/v1 branch
└── release/v2 branch

iqq-product-service/ (separate repository)
├── release/v1 branch
└── release/v2 branch

iqq-document-service/ (separate repository)
├── release/v1 branch
└── release/v2 branch

iqq-infrastructure/ (separate repository)
├── release/v1 branch
└── release/v2 branch
```

## How to Use

### Creating Release Branches

1. **Navigate to the root repository** (iqq-project):
   ```bash
   cd iqq-project
   ```

2. **Ensure all service repositories are cloned** as sibling directories:
   ```bash
   ls -la ../
   # Should show: iqq-package-service, iqq-lender-service, etc.
   ```

3. **Run the branch creation script**:
   ```bash
   # Create v1 branches
   ./scripts/create-release-branches.sh v1
   
   # Create v2 branches
   ./scripts/create-release-branches.sh v2
   ```

4. **Verify branches were created**:
   ```bash
   # Check each repository
   cd ../iqq-package-service && git branch -a
   cd ../iqq-lender-service && git branch -a
   # etc.
   ```

### Managing Version Policy

#### View Current Configuration

```bash
# Get current version
jq -r '.currentVersion' config/version-policy.json

# List all supported versions
jq -r '.supportedVersions[]' config/version-policy.json

# Check version status
jq -r '.versions.v1.status' config/version-policy.json
```

#### Update Version Status

```bash
# Mark v1 as deprecated
jq '.versions.v1.status = "deprecated" | 
    .versions.v1.sunsetDate = "2026-12-31T23:59:59Z"' \
    config/version-policy.json > config/version-policy.json.tmp
mv config/version-policy.json.tmp config/version-policy.json

# Promote v2 to stable
jq '.versions.v2.status = "stable" | 
    .currentVersion = "v2"' \
    config/version-policy.json > config/version-policy.json.tmp
mv config/version-policy.json.tmp config/version-policy.json
```

#### Add Breaking Changes

```bash
jq '.versions.v2.breakingChanges += ["Removed deprecated field: oldField"]' \
    config/version-policy.json > config/version-policy.json.tmp
mv config/version-policy.json.tmp config/version-policy.json
```

## Version Lifecycle

### 1. Planned
- Version defined in version-policy.json
- Status: `"planned"`
- No release branches yet
- No Lambda aliases yet

### 2. Alpha (Internal Testing)
- Release branches created
- Status: `"alpha"`
- Lambda aliases created
- Breaking changes allowed
- Internal testing only

### 3. Beta (Partner Testing)
- Status: `"beta"`
- Selected partners have access
- Minimal breaking changes
- Migration guide available

### 4. Stable (Production)
- Status: `"stable"`
- All clients can use
- No breaking changes allowed
- Full support provided

### 5. Deprecated
- Status: `"deprecated"`
- Sunset date set
- Deprecation warnings in responses
- Security fixes only
- Migration guide required

### 6. Sunset (End of Life)
- Status: `"sunset"`
- API Gateway stage removed
- Lambda aliases removed
- No longer accessible

## Integration Points

### GitHub Actions (Future)

The version policy will be used by:

1. **deploy-version.yml**: Validates version before deployment
2. **deprecate-version.yml**: Updates version status
3. **sunset-version.yml**: Removes deprecated versions

### Lambda Functions

Each Lambda function will:
- Read version from `event.requestContext.stage`
- Add version headers to responses
- Include deprecation warnings when applicable

### API Gateway

API Gateway stages will:
- Map to version names (v1, v2)
- Use stage variables to route to Lambda aliases
- Include version in access logs

## Next Steps

With Task 1 complete, proceed to:

1. **Task 2**: Update Terraform for stage-based versioning
   - Create v1 and v2 API Gateway stages
   - Update Lambda permissions
   - Configure stage variables

2. **Task 3**: Implement Lambda version headers
   - Create response builder utility
   - Add version policy to each service
   - Update Lambda handlers

3. **Task 4**: Set up GitHub Actions workflows
   - Create deployment orchestration
   - Implement deprecation workflow
   - Add sunset automation

## Troubleshooting

### Branch Creation Fails

**Problem**: Script can't find service repositories

**Solution**: Ensure all service repos are cloned as siblings:
```bash
cd ..
git clone https://github.com/rgcleanslage/iqq-package-service
git clone https://github.com/rgcleanslage/iqq-lender-service
git clone https://github.com/rgcleanslage/iqq-product-service
git clone https://github.com/rgcleanslage/iqq-document-service
git clone https://github.com/rgcleanslage/iqq-infrastructure
cd iqq-project
```

### Branch Already Exists

**Problem**: Branch already exists locally or remotely

**Solution**: Script will prompt to recreate or skip. Choose based on your needs.

### Permission Denied

**Problem**: Can't push to remote repository

**Solution**: Ensure you have write access to all repositories and GitHub authentication is configured.

## References

- [API Versioning Requirements](../../.kiro/specs/api-versioning/requirements.md)
- [API Versioning Design](../../.kiro/specs/api-versioning/design.md)
- [API Versioning Tasks](../../.kiro/specs/api-versioning/tasks.md)
- [Repository Structure](../../REPOSITORIES.md)
- [Version Policy Configuration](../../config/README.md)

---

**Task Status**: ✅ Complete  
**Completed**: February 18, 2026  
**Next Task**: Task 2 - Update Terraform for stage-based versioning
