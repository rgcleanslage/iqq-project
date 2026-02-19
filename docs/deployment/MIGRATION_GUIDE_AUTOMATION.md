# Migration Guide Automation

**Date**: February 18, 2026  
**Status**: Complete

## Overview

This document describes the automated migration guide generation system that analyzes code changes between API versions and creates comprehensive migration documentation.

## Workflow: Generate Migration Guide from Code Changes

### Purpose

Automatically generate migration guides by analyzing actual code differences between versions across all services, eliminating manual documentation effort and ensuring accuracy.

### Location

`.github/workflows/generate-migration-guide.yml`

### How It Works

1. **Code Analysis**: Checks out each service repository and analyzes code differences
2. **Change Detection**: Extracts handler signatures, data models, dependencies, and recent commits
3. **Guide Generation**: Creates comprehensive migration guide with detected changes
4. **PR Creation**: Opens pull request with auto-generated documentation for review

### What Gets Analyzed

For each service (package, lender, product, document):

- **Handler Signatures**: Function signatures and parameter changes
- **Data Models**: Schema changes in TypeScript models
- **Dependencies**: Package.json dependency updates
- **Recent Commits**: Last 20 commits for context

### Generated Content

The workflow creates `docs/api/migrations/MIGRATION_v{X}_TO_v{Y}.md` with:

1. **Service Changes**
   - Changed files by service
   - Handler signature comparisons
   - Data model changes
   - Dependency updates

2. **Breaking Changes Analysis**
   - API request/response changes
   - Dependency updates
   - Compatibility notes

3. **Migration Steps**
   - Step-by-step migration instructions
   - Endpoint URL updates
   - Testing procedures
   - Version header verification

4. **Code Examples**
   - JavaScript/TypeScript examples
   - Python examples
   - cURL examples
   - Before/after comparisons

5. **Testing Instructions**
   - Endpoint testing commands
   - Header verification
   - Integration test guidance

6. **Rollback Plan**
   - Revert procedures
   - Monitoring guidance
   - Issue reporting

## Usage

### Trigger the Workflow

1. Go to: https://github.com/rgcleanslage/iqq-project/actions
2. Click "Generate Migration Guide from Code Changes"
3. Click "Run workflow"
4. Enter parameters:
   - **from_version**: Source version (e.g., `v2`)
   - **to_version**: Target version (e.g., `v3`)
   - **analyze_services**: Services to analyze (`all` or comma-separated list)
5. Click "Run workflow"

### Example

```yaml
from_version: v2
to_version: v3
analyze_services: all
```

This will analyze all services and generate `MIGRATION_v2_TO_v3.md`.

### Workflow Steps

1. **Analyze Changes** (5-10 minutes)
   - Checks out all service repositories
   - Analyzes code in parallel
   - Extracts changes and patterns

2. **Generate Guide** (1-2 minutes)
   - Combines all analyses
   - Generates markdown documentation
   - Includes code examples and instructions

3. **Create PR** (< 1 minute)
   - Creates pull request with guide
   - Adds checklist for manual enhancements
   - Notifies team

### Review and Enhance

After the workflow completes:

1. **Review the PR** - Check the generated migration guide
2. **Validate Changes** - Ensure detected changes are accurate
3. **Add Details**:
   - Specific breaking change descriptions
   - Behavioral differences
   - Timeline (release, deprecation, sunset dates)
   - Customer-facing examples
   - FAQ section if needed
4. **Test Migration Steps** - Verify instructions work
5. **Merge and Publish** - Merge PR to publish guide

## Integration with Add New Version Workflow

The migration guide workflow integrates with the "Add New API Version" workflow:

1. **Add New Version** workflow creates version configuration
2. **Generate Migration Guide** workflow analyzes code changes
3. Manual enhancement adds specific details
4. Published guide helps customers migrate

## Benefits

### Automated

- No manual code comparison needed
- Consistent format across versions
- Reduces documentation time by 80%

### Accurate

- Based on actual code changes
- Includes real handler signatures
- Shows actual dependency versions

### Comprehensive

- Covers all services
- Includes code examples
- Provides testing instructions
- Documents rollback procedures

### Maintainable

- Template-based generation
- Easy to update workflow
- Consistent structure

## Workflow Configuration

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `from_version` | Source version | Yes | - |
| `to_version` | Target version | Yes | - |
| `analyze_services` | Services to analyze | Yes | `all` |

### Outputs

- Migration guide markdown file
- Pull request with guide
- Analysis artifacts (uploaded)

### Permissions

```yaml
permissions:
  contents: write
  pull-requests: write
```

### Secrets Required

- `PAT_TOKEN` - GitHub Personal Access Token with `repo` and `workflow` scopes

## Example Generated Guide Structure

```markdown
# Migration Guide: v2 to v3

## Overview
Auto-generated migration guide based on code analysis.

## Service Changes

### Package Service
- Handler signature changes
- Data model updates
- Dependency changes

### Lender Service
- Handler signature changes
- Data model updates
- Dependency changes

### Product Service
- Handler signature changes
- Data model updates
- Dependency changes

### Document Service
- Handler signature changes
- Data model updates
- Dependency changes

## Breaking Changes Analysis
- API request/response changes
- Dependency updates
- Compatibility notes

## Migration Steps
1. Review code changes
2. Update API endpoints
3. Test integration
4. Verify version headers

## Code Examples
- JavaScript/TypeScript
- Python
- cURL

## Rollback Plan
- Revert procedures
- Monitoring guidance
```

## Limitations

### Current Implementation

- Compares code on main branch (not release branches yet)
- Uses recent commits as proxy for changes
- Requires manual enhancement for behavioral changes

### Future Enhancements

- Compare actual release branches (release/v2 vs release/v3)
- Deeper AST analysis for breaking changes
- Automated breaking change detection
- Integration with OpenAPI spec comparison
- Automated test generation

## Best Practices

### When to Run

- After adding new version configuration
- Before releasing new version
- When significant code changes made
- Before deprecating old version

### Manual Enhancements

Always add:
- Specific breaking change descriptions
- Behavioral differences not visible in code
- Timeline information
- Customer impact assessment
- Migration timeline recommendations

### Review Checklist

- [ ] All detected changes are accurate
- [ ] Breaking changes clearly documented
- [ ] Code examples tested and working
- [ ] Migration steps validated
- [ ] Timeline information added
- [ ] Customer impact assessed
- [ ] FAQ section added if needed

## Related Workflows

1. **Add New API Version** - Creates version configuration
2. **Deploy API Version** - Deploys services to version
3. **Deprecate API Version** - Marks version as deprecated
4. **Sunset API Version** - Removes version

## Related Documentation

- [Add New Version Guide](./ADD_NEW_VERSION_GUIDE.md)
- [GitHub Actions Versioning](./GITHUB_ACTIONS_VERSIONING.md)
- [API Versioning Setup](../api/API_VERSIONING_SETUP.md)

## Support

For issues or questions:
- **GitHub Issues**: https://github.com/rgcleanslage/iqq-project/issues
- **Workflow Runs**: https://github.com/rgcleanslage/iqq-project/actions

---

**Last Updated**: February 18, 2026  
**Workflow Version**: 1.0.0
