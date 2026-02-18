# API Version Configuration

This directory contains centralized configuration for API versioning across all iQQ platform services.

## Files

### version-policy.json

Central configuration file that defines:
- **Current version**: The active stable version
- **Supported versions**: List of all supported API versions
- **Version metadata**: Status, sunset dates, migration guides for each version
- **Service mappings**: Repository URLs and Lambda function names
- **Deprecation policy**: Rules for version lifecycle management

## Version Lifecycle

### Version Statuses

- **planned**: Version is defined but not yet released
- **alpha**: Internal testing only, breaking changes allowed
- **beta**: Selected partners, minimal breaking changes
- **stable**: Production-ready, no breaking changes
- **deprecated**: Still supported but scheduled for removal
- **sunset**: No longer supported, removed from API Gateway

### Deprecation Timeline

Based on `deprecationPolicy` in version-policy.json:
- **Warning Period**: 90 days - Deprecation warnings sent in API responses
- **Sunset Period**: 180 days - Total time before version is removed
- **Minimum Versions**: 2 - Maximum concurrent versions supported

## Usage

### Reading Version Policy

```bash
# Get current version
jq -r '.currentVersion' config/version-policy.json

# Get all supported versions
jq -r '.supportedVersions[]' config/version-policy.json

# Get version status
jq -r '.versions.v1.status' config/version-policy.json

# Get service repository URLs
jq -r '.services.package.repository' config/version-policy.json
```

### Updating Version Policy

```bash
# Mark version as deprecated
jq '.versions.v1.status = "deprecated" | 
    .versions.v1.sunsetDate = "2026-12-31T23:59:59Z"' \
    config/version-policy.json > config/version-policy.json.tmp
mv config/version-policy.json.tmp config/version-policy.json

# Update current version
jq '.currentVersion = "v2"' config/version-policy.json > config/version-policy.json.tmp
mv config/version-policy.json.tmp config/version-policy.json

# Add breaking change
jq '.versions.v2.breakingChanges += ["Removed deprecated field: oldField"]' \
    config/version-policy.json > config/version-policy.json.tmp
mv config/version-policy.json.tmp config/version-policy.json
```

## Integration with GitHub Actions

The version policy is used by GitHub Actions workflows in `.github/workflows/`:

- **deploy-version.yml**: Validates version exists before deployment
- **deprecate-version.yml**: Updates version status to deprecated
- **sunset-version.yml**: Removes deprecated versions

## Service Repositories

All service repositories are separate GitHub repositories:

- **iqq-package-service**: Package aggregation service
- **iqq-lender-service**: Lender information service
- **iqq-product-service**: Product information service
- **iqq-document-service**: Document management service
- **iqq-infrastructure**: Terraform infrastructure as code

Each service repository should have:
- Release branches: `release/v1`, `release/v2`, etc.
- Lambda aliases: `v1`, `v2`, etc.
- Version-specific configuration

## Creating Release Branches

Use the helper script to create release branches across all repositories:

```bash
# Create v1 release branches
./scripts/create-release-branches.sh v1

# Create v2 release branches
./scripts/create-release-branches.sh v2
```

This script will:
1. Create `release/v1` or `release/v2` branches in each service repository
2. Push branches to remote
3. Provide a summary of success/failures

## Version Policy Schema

```json
{
  "currentVersion": "string (v1, v2, etc.)",
  "supportedVersions": ["array of version strings"],
  "versions": {
    "<version>": {
      "status": "planned|alpha|beta|stable|deprecated|sunset",
      "sunsetDate": "ISO 8601 date or null",
      "migrationGuide": "URL or null",
      "lambdaAlias": "Lambda alias name",
      "description": "Version description",
      "releaseDate": "ISO 8601 date or null",
      "lastDeployed": "ISO 8601 date or null",
      "breakingChanges": ["array of breaking change descriptions"]
    }
  },
  "deprecationPolicy": {
    "warningPeriodDays": 90,
    "sunsetPeriodDays": 180,
    "minimumSupportedVersions": 2
  },
  "services": {
    "<service-name>": {
      "repository": "GitHub repository URL",
      "lambdaFunction": "Lambda function name"
    }
  },
  "infrastructure": {
    "repository": "GitHub repository URL",
    "apiGatewayId": "API Gateway REST API ID"
  },
  "metadata": {
    "lastUpdated": "ISO 8601 timestamp",
    "updatedBy": "User or system identifier",
    "schemaVersion": "Schema version"
  }
}
```

## Best Practices

1. **Always update lastUpdated**: When modifying version-policy.json
2. **Document breaking changes**: Add to breakingChanges array
3. **Set sunset dates**: When deprecating a version
4. **Maintain migration guides**: Create docs before deprecating
5. **Test before deploying**: Validate JSON syntax and schema
6. **Commit changes**: Version policy changes should be tracked in git

## Related Documentation

- [API Versioning Requirements](.kiro/specs/api-versioning/requirements.md)
- [API Versioning Design](.kiro/specs/api-versioning/design.md)
- [API Versioning Tasks](.kiro/specs/api-versioning/tasks.md)
- [Repository Structure](../REPOSITORIES.md)

---

**Last Updated**: February 18, 2026  
**Schema Version**: 1.0.0
