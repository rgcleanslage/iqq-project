# API Versioning Manual — GitHub Releases

This is the definitive guide for managing API versions in the iQQ platform. All version tracking is done through GitHub Releases on the root repository (`iqq-project`).

## How It Works

Each API version is represented by a GitHub Release with the tag `api-{version}` (e.g., `api-v1`, `api-v2`). The release body contains a JSON metadata block that stores version status, sunset dates, migration info, and deploy timestamps.

The GitHub Actions workflows read and write this metadata directly — there are no config files to maintain.

## Version Lifecycle

```
planned → alpha → beta → stable → deprecated → sunset
```

| Status | Meaning |
|---|---|
| planned | Defined, not yet deployed |
| alpha | Internal testing, breaking changes allowed |
| beta | Partner testing, minimal breaking changes |
| stable | Production-ready, current version |
| deprecated | Still running, scheduled for removal (90+ day notice) |
| sunset | Removed from API Gateway, no longer accessible |

## Release Tag Convention

All version releases use the prefix `api-`:

```
api-v1    ← stable (full release)
api-v2    ← planned (pre-release)
api-v4    ← planned (pre-release)
```

Stable versions are full releases. Everything else is marked as a pre-release.

## Release Metadata Format

Every release body contains a fenced JSON block that the workflows parse:

```json
{
  "version": "v1",
  "status": "stable",
  "sunsetDate": null,
  "migrationGuide": null,
  "lambdaAlias": "v1",
  "releaseDate": "2026-02-18T00:00:00Z",
  "lastDeployed": "2026-02-19T14:30:00Z",
  "previousVersion": null
}
```

| Field | Description |
|---|---|
| version | Version identifier (v1, v2, etc.) |
| status | Current lifecycle status |
| sunsetDate | ISO timestamp when version will be removed (null if not deprecated) |
| migrationGuide | URL to migration documentation |
| lambdaAlias | Lambda alias name (matches version) |
| releaseDate | When the version was created |
| lastDeployed | Last successful deployment timestamp |
| previousVersion | The version this one succeeds |

---

## Workflows

All workflows are in `.github/workflows/` on the root repository and are triggered manually via `workflow_dispatch`.

### 1. Add New API Version

**Workflow**: `add-new-version.yml`
**When to use**: You want to create a new API version.

**Inputs**:
| Input | Required | Description |
|---|---|---|
| new_version | Yes | Version tag, e.g. `v5` |
| status | Yes | Initial status: `planned`, `alpha`, or `beta` |
| migration_guide_url | No | URL for migration docs |
| package_branch | No | Source branch for package service (default: main) |
| lender_branch | No | Source branch for lender service (default: main) |
| product_branch | No | Source branch for product service (default: main) |
| document_branch | No | Source branch for document service (default: main) |
| infrastructure_branch | No | Source branch for infrastructure (default: main) |

**What it does**:
1. Validates the version format and checks it doesn't already exist
2. Creates a GitHub Release `api-{version}` with metadata
3. Generates a migration guide template in `docs/api/migrations/`
4. Creates an API Gateway stage for the new version
5. Adds Lambda permissions for all 4 services
6. Creates `release/{version}` branches in all service repos

**Example**:
```
Go to: Actions → Add New API Version → Run workflow
  new_version: v5
  status: planned
```

### 2. Update Version Status

**Workflow**: `update-version-status.yml`
**When to use**: You want to promote a version through its lifecycle (planned → alpha → beta → stable).

**Inputs**:
| Input | Required | Description |
|---|---|---|
| version | Yes | Version to update, e.g. `v2` |
| new_status | Yes | New status: `planned`, `alpha`, `beta`, `stable`, `deprecated`, `sunset` |
| make_current | No | Mark as current stable version (only for stable status) |

**What it does**:
1. Validates the version exists as a GitHub Release
2. Updates the status in the release metadata
3. Changes pre-release flag (stable = full release, others = pre-release)
4. Warns about unusual status transitions
5. Optionally marks the version as the current stable version

**Example**:
```
Go to: Actions → Update Version Status → Run workflow
  version: v2
  new_status: stable
  make_current: true
```

**Note**: For deprecating versions, use the "Deprecate API Version" workflow instead — it sets sunset dates and triggers redeployments.

### 3. Deploy API Version

**Workflow**: `deploy-version.yml`
**When to use**: You want to deploy (or redeploy) services for a specific version.

**Inputs**:
| Input | Required | Description |
|---|---|---|
| version | Yes | Version to deploy, e.g. `v1` |
| deploy_all | No | Deploy all 4 services (default: true) |
| deploy_package | No | Deploy package service only |
| deploy_lender | No | Deploy lender service only |
| deploy_product | No | Deploy product service only |
| deploy_document | No | Deploy document service only |
| environment | Yes | Target environment (currently: `dev`) |

**What it does**:
1. Validates the version exists as a GitHub Release and isn't sunset
2. Triggers deployment in each selected service repo
3. Monitors deployment progress
4. Tests all endpoints and verifies responses
5. Redeploys the API Gateway stage
6. Updates the release metadata with the deploy timestamp

### 4. Deprecate API Version

**Workflow**: `deprecate-version.yml`
**When to use**: You want to mark a version as deprecated and schedule its removal.

**Inputs**:
| Input | Required | Description |
|---|---|---|
| version | Yes | Version to deprecate, e.g. `v1` |
| sunset_date | Yes | Removal date in `YYYY-MM-DD` format |
| migration_guide_url | Yes | URL to migration guide |

**What it does**:
1. Validates the version isn't the current stable version
2. Ensures sunset date is in the future (warns if < 90 days)
3. Updates the GitHub Release metadata to `deprecated` with sunset date
4. Triggers redeployment of all services so deprecation headers take effect

**Deprecation headers added to responses**:
```
X-API-Deprecated: true
X-API-Sunset-Date: 2026-12-31
Warning: 299 - "API version v1 is deprecated. Please migrate to v2 by 2026-12-31."
```

### 5. Sunset API Version

**Workflow**: `sunset-version.yml`
**When to use**: You want to permanently remove a deprecated version.

**Inputs**:
| Input | Required | Description |
|---|---|---|
| version | Yes | Version to sunset, e.g. `v1` |
| confirm | Yes | Type `CONFIRM` to proceed |

**What it does**:
1. Validates the version isn't the current stable version
2. Removes the API Gateway stage (version URL stops working)
3. Deletes Lambda aliases for all 4 services
4. Updates the GitHub Release metadata to `sunset`
5. Creates an archive in `docs/api/archive/{version}/`

---

## Deprecation Headers in Services

Services read deprecation info from Lambda environment variables at runtime:

| Env Variable | Description |
|---|---|
| `VERSION_STATUS` | `stable`, `deprecated`, etc. |
| `VERSION_SUNSET_DATE` | ISO date or empty |
| `VERSION_MIGRATION_GUIDE` | URL or empty |
| `VERSION_CURRENT` | The current stable version |

These should be set on the Lambda function configuration during deployment. The `response-builder.ts` utility in each service reads these to set the appropriate response headers.

---

## CLI Quick Reference

### List all API versions
```bash
gh release list | grep "api-"
```

### View a specific version's metadata
```bash
gh release view api-v1 --json body --jq '.body'
```

### Extract just the JSON metadata
```bash
gh release view api-v1 --json body --jq '.body' | sed -n '/```json/,/```/p' | sed '1d;$d' | jq .
```

### Find the current stable version
```bash
gh release list --json tagName,body --limit 100 | \
  jq -r '[.[] | select(.tagName | startswith("api-")) |
    select(.body | contains("\"status\": \"stable\""))] | .[].tagName'
```

### List all deprecated versions
```bash
gh release list --json tagName,body --limit 100 | \
  jq -r '[.[] | select(.tagName | startswith("api-")) |
    select(.body | contains("\"status\": \"deprecated\""))] | .[].tagName'
```

---

## Typical Version Lifecycle Example

```bash
# 1. Create v3
#    Actions → Add New API Version → new_version: v3, status: planned

# 2. Promote v3 to alpha for internal testing
#    Actions → Update Version Status → version: v3, new_status: alpha

# 3. Deploy v3 for testing
#    Actions → Deploy API Version → version: v3

# 4. Promote v3 to beta for partner testing
#    Actions → Update Version Status → version: v3, new_status: beta

# 5. When v3 is ready, promote to stable
#    Actions → Update Version Status → version: v3, new_status: stable, make_current: true

# 6. Deprecate v1 with 90-day notice
#    Actions → Deprecate API Version → version: v1, sunset_date: 2026-06-01

# 7. After sunset date, remove v1
#    Actions → Sunset API Version → version: v1, confirm: CONFIRM
```

---

## Repository Structure

```
iqq-project (root)
├── .github/workflows/
│   ├── add-new-version.yml
│   ├── update-version-status.yml
│   ├── deploy-version.yml
│   ├── deprecate-version.yml
│   └── sunset-version.yml
├── config/
│   └── README.md
├── docs/api/migrations/
│   └── MIGRATION_v1_TO_v2.md
└── docs/api/archive/
    └── v1/README.md          ← created on sunset
```

Version data lives in GitHub Releases, not in files.

---

**Last Updated**: February 19, 2026
