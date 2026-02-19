# API Version Configuration

Version tracking is managed via **GitHub Releases** (tags: `api-v1`, `api-v2`, etc.).

Each release contains a JSON metadata block in its body with version status, sunset dates, migration guides, and deploy timestamps.

## Version Lifecycle

| Status | Description |
|--------|-------------|
| planned | Defined but not yet released |
| alpha | Internal testing, breaking changes allowed |
| beta | Selected partners, minimal breaking changes |
| stable | Production-ready, no breaking changes |
| deprecated | Still supported but scheduled for removal |
| sunset | Removed from API Gateway |

### Deprecation Policy
- Warning Period: 90 days
- Sunset Period: 180 days
- Minimum Supported Versions: 2

## Reading Version Info

```bash
# List all API versions
gh release list --json tagName,name | jq '[.[] | select(.tagName | startswith("api-"))]'

# Get metadata for a specific version
gh release view "api-v1" --json body --jq '.body'

# Find the current stable version
gh release list --json tagName,body --limit 100 | \
  jq '[.[] | select(.tagName | startswith("api-")) | select(.body | contains("\"status\": \"stable\""))]'
```

## GitHub Actions Workflows

- **add-new-version.yml**: Creates a GitHub Release with version metadata
- **deploy-version.yml**: Validates version from release, deploys services, updates release metadata
- **deprecate-version.yml**: Updates release status to deprecated
- **sunset-version.yml**: Updates release status to sunset, removes infrastructure

## Release Tag Convention

Tags follow the pattern `api-{version}`, e.g. `api-v1`, `api-v2`, `api-v4`.

## Related Documentation

- [API Versioning Setup](../docs/api/API_VERSIONING_SETUP.md)
- [Deployment Guide](../docs/deployment/DEPLOYMENT_GUIDE.md)

---

**Last Updated**: February 19, 2026
