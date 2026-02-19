# Add New API Version Workflow Guide

**Workflow File**: `.github/workflows/add-new-version.yml`  
**Purpose**: Automate the process of adding a new API version across all repositories  
**Status**: ✅ Ready to use (with prerequisites)

## Overview

The "Add New API Version" workflow automates the complex process of introducing a new API version to the iQQ system. It creates pull requests across multiple repositories, generates migration documentation, and provides infrastructure configuration templates.

## What This Workflow Does

When you run this workflow, it will:

### 1. Validate the New Version
- Checks version format (must be `v3`, `v4`, `v5`, etc.)
- Verifies the version doesn't already exist
- Identifies the previous version for migration guide generation

### 2. Create Migration Guide
- Generates a comprehensive migration guide template
- Includes code examples in JavaScript/TypeScript, Python, and cURL
- Provides step-by-step migration instructions
- Creates testing commands for all endpoints
- Saves to `docs/api/migrations/MIGRATION_v{X}_TO_v{Y}.md`

### 3. Update Root Repository (iqq-project)
- Updates `config/version-policy.json` with new version
- Adds version to workflow dropdown options:
  - `deploy-version.yml`
  - `deprecate-version.yml`
  - `sunset-version.yml`
- Creates a pull request with all changes

### 4. Update Infrastructure Repository (iqq-infrastructure)
- Generates Terraform configuration for:
  - New API Gateway stage
  - Lambda permissions for all 4 services
  - Stage output variables
- Creates `INFRASTRUCTURE_UPDATE.md` with manual steps
- Creates a pull request with instructions

### 5. Update Service Repositories
- Updates `src/config/version-policy.json` in each service:
  - iqq-package-service
  - iqq-lender-service
  - iqq-product-service
  - iqq-document-service
- Creates pull requests in all 4 service repositories

## Prerequisites

### Required Secrets

The workflow requires the following GitHub secret to be configured:

#### `PAT_TOKEN` (Personal Access Token)
- **Purpose**: Create pull requests across multiple repositories
- **Required Permissions**:
  - `repo` (Full control of private repositories)
  - `workflow` (Update GitHub Action workflows)
- **Scope**: Must have access to all repositories:
  - rgcleanslage/iqq-project
  - rgcleanslage/iqq-infrastructure
  - rgcleanslage/iqq-package-service
  - rgcleanslage/iqq-lender-service
  - rgcleanslage/iqq-product-service
  - rgcleanslage/iqq-document-service

#### How to Create PAT_TOKEN:
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Name: `iQQ API Versioning Workflow`
4. Select scopes:
   - ✅ `repo` (all sub-scopes)
   - ✅ `workflow`
5. Click "Generate token"
6. Copy the token immediately (you won't see it again)
7. Add to repository secrets:
   - Go to iqq-project repository
   - Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `PAT_TOKEN`
   - Value: [paste your token]
   - Click "Add secret"

### Repository Access

The workflow must have access to all 6 repositories listed above. Ensure:
- The PAT_TOKEN has access to all repositories
- All repositories exist and are accessible
- The GitHub organization name is correct (`rgcleanslage`)

## How to Use

### Step 1: Trigger the Workflow

1. Go to the iqq-project repository on GitHub
2. Click "Actions" tab
3. Select "Add New API Version" workflow
4. Click "Run workflow"
5. Fill in the inputs:

#### Input Parameters

| Parameter | Description | Required | Options/Format | Default |
|-----------|-------------|----------|----------------|---------|
| `new_version` | New version to add | Yes | `v3`, `v4`, `v5`, etc. | - |
| `status` | Initial version status | Yes | `planned`, `alpha`, `beta` | `planned` |
| `migration_guide_url` | Migration guide base URL | No | URL string | `https://docs.iqq.com/api/migration` |

#### Example Inputs:
```
new_version: v3
status: planned
migration_guide_url: https://docs.iqq.com/api/migration
```

### Step 2: Review Pull Requests

The workflow will create 6 pull requests:

#### 1. Root Repository PR (iqq-project)
**Title**: "Add API Version v3"

**Changes**:
- `config/version-policy.json` - Added v3 configuration
- `.github/workflows/deploy-version.yml` - Added v3 to dropdown
- `.github/workflows/deprecate-version.yml` - Added v3 to dropdown
- `.github/workflows/sunset-version.yml` - Added v3 to dropdown
- `docs/api/migrations/MIGRATION_v2_TO_v3.md` - New migration guide

**Action**: Review and merge

#### 2. Infrastructure Repository PR (iqq-infrastructure)
**Title**: "Infrastructure: Add API Version v3"

**Changes**:
- `INFRASTRUCTURE_UPDATE.md` - Manual steps and Terraform code

**Action**: 
1. Review the PR
2. Follow instructions in `INFRASTRUCTURE_UPDATE.md`
3. Manually add Terraform configuration
4. Run `terraform apply`
5. Close the PR (or merge if you added the code)

#### 3-6. Service Repository PRs
**Repositories**:
- iqq-package-service
- iqq-lender-service
- iqq-product-service
- iqq-document-service

**Title**: "Add Version v3 Configuration"

**Changes**:
- `src/config/version-policy.json` - Added v3 configuration

**Action**: Review and merge all 4 PRs

### Step 3: Update Infrastructure (Manual)

The infrastructure changes must be applied manually for safety:

#### 3.1 Add API Gateway Stage

Edit `iqq-infrastructure/modules/api-gateway/main.tf`:

```hcl
# v3 stage
resource "aws_api_gateway_stage" "v3" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "v3"
  
  variables = {
    lambdaAlias = "v3"
  }
  
  xray_tracing_enabled = true
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      stage          = "$context.stage"
      lambdaAlias    = "$stageVariables.lambdaAlias"
    })
  }
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-api-v3-${var.environment}"
      Stage       = "v3"
      Environment = var.environment
    }
  )
}
```

#### 3.2 Add Lambda Permissions

Add these 4 permission resources to `modules/api-gateway/main.tf`:

```hcl
# Lambda permissions for v3
resource "aws_lambda_permission" "package_v3" {
  statement_id  = "AllowAPIGatewayInvokeV3"
  function_name = var.package_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/v3/GET/package"
  qualifier     = "v3"
}

resource "aws_lambda_permission" "lender_v3" {
  statement_id  = "AllowAPIGatewayInvokeV3"
  function_name = var.lender_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/v3/GET/lender"
  qualifier     = "v3"
}

resource "aws_lambda_permission" "product_v3" {
  statement_id  = "AllowAPIGatewayInvokeV3"
  function_name = var.product_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/v3/GET/product"
  qualifier     = "v3"
}

resource "aws_lambda_permission" "document_v3" {
  statement_id  = "AllowAPIGatewayInvokeV3"
  function_name = var.document_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/v3/GET/document"
  qualifier     = "v3"
}
```

#### 3.3 Add Output

Edit `iqq-infrastructure/modules/api-gateway/outputs.tf`:

```hcl
output "v3_stage_url" {
  description = "URL for v3 stage"
  value       = "${aws_api_gateway_stage.v3.invoke_url}"
}
```

#### 3.4 Apply Terraform

```bash
cd iqq-infrastructure
terraform init
terraform plan  # Review changes
terraform apply # Apply changes
```

#### 3.5 Verify Stage

```bash
aws apigateway get-stage \
  --rest-api-id $(terraform output -raw api_gateway_id) \
  --stage-name v3 \
  --region us-east-1
```

### Step 4: Deploy Services

After infrastructure is ready, deploy all services using the "Deploy API Version" workflow:

1. Go to iqq-project repository → Actions
2. Select "Deploy API Version" workflow
3. Click "Run workflow"
4. Fill in inputs:
   ```
   version: v3
   services: all
   environment: dev
   ```
5. Click "Run workflow"

This will:
- Deploy all 4 services
- Publish new Lambda versions
- Create v3 aliases pointing to new versions
- Verify deployments

### Step 5: Test the New Version

Test all endpoints with the new version:

```bash
# Set your credentials
export TOKEN="your-oauth-token"
export API_KEY="your-api-key"

# Test package endpoint
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# Test lender endpoint
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/lender?lenderId=LENDER-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# Test product endpoint
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/product?productId=PROD-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

# Test document endpoint
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/document" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

Verify version headers:
```bash
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY" | grep -i "x-api-version"

# Should return: x-api-version: v3
```

### Step 6: Update Migration Guide

The generated migration guide is a template. Update it with actual changes:

1. Open `docs/api/migrations/MIGRATION_v2_TO_v3.md`
2. Document breaking changes
3. Add new features
4. Update code examples
5. Add specific migration steps
6. Commit and push changes

## Workflow Jobs

The workflow consists of 6 jobs that run in sequence:

### Job 1: validate-version
- **Duration**: ~5 seconds
- **Purpose**: Validate version format and check for duplicates
- **Outputs**: `version`, `previous-version`

### Job 2: create-migration-guide
- **Duration**: ~10 seconds
- **Purpose**: Generate migration guide template
- **Artifacts**: Migration guide markdown file

### Job 3: update-root-config
- **Duration**: ~15 seconds
- **Purpose**: Update root repository configuration
- **Creates**: Pull request in iqq-project

### Job 4: update-infrastructure
- **Duration**: ~20 seconds
- **Purpose**: Generate infrastructure configuration
- **Creates**: Pull request in iqq-infrastructure

### Job 5: update-service-configs
- **Duration**: ~30 seconds (runs in parallel for 4 services)
- **Purpose**: Update service version policies
- **Creates**: 4 pull requests (one per service)

### Job 6: notify-completion
- **Duration**: ~5 seconds
- **Purpose**: Display summary and next steps

**Total Duration**: ~1-2 minutes

## Generated Files

### Migration Guide
**Location**: `docs/api/migrations/MIGRATION_v{X}_TO_v{Y}.md`

**Contents**:
- Overview of changes
- Breaking changes section
- Deprecated features
- Step-by-step migration instructions
- Code examples (JavaScript, Python, cURL)
- API endpoint comparison table
- Version headers documentation
- Rollback plan
- Support information
- Migration checklist

### Infrastructure Instructions
**Location**: `iqq-infrastructure/INFRASTRUCTURE_UPDATE.md`

**Contents**:
- Terraform stage configuration
- Lambda permission resources
- Output configuration
- Apply commands
- Verification steps

## Version Status Options

When creating a new version, you can set its initial status:

### `planned`
- Version is planned but not yet implemented
- No code changes required yet
- Used for roadmap planning
- **Use when**: Planning future versions

### `alpha`
- Version is in early development
- May have incomplete features
- Breaking changes expected
- Limited testing
- **Use when**: Initial development phase

### `beta`
- Version is feature-complete
- Undergoing testing
- Minor changes possible
- Ready for early adopters
- **Use when**: Testing phase before production

### `stable` (set later via deprecate workflow)
- Version is production-ready
- Fully tested and documented
- Recommended for production use
- **Set when**: Version is released

### `deprecated` (set via deprecate workflow)
- Version is still available but not recommended
- Will be sunset in the future
- Clients should migrate to newer version
- **Set when**: Preparing to sunset a version

### `sunset` (set via sunset workflow)
- Version is no longer available
- All traffic should use newer versions
- **Set when**: Removing a version

## Troubleshooting

### Issue: PAT_TOKEN not found
**Error**: `Error: Input required and not supplied: token`

**Solution**: 
1. Create a Personal Access Token (see Prerequisites)
2. Add it as a repository secret named `PAT_TOKEN`

### Issue: Permission denied when creating PR
**Error**: `Resource not accessible by integration`

**Solution**:
1. Verify PAT_TOKEN has `repo` and `workflow` scopes
2. Ensure token has access to all 6 repositories
3. Check token hasn't expired

### Issue: Version already exists
**Error**: `Version v3 already exists in configuration`

**Solution**:
1. Check `config/version-policy.json` for existing version
2. Use a different version number
3. Or remove the existing version first (if appropriate)

### Issue: Terraform apply fails
**Error**: Various Terraform errors

**Solution**:
1. Review the generated Terraform code carefully
2. Check for syntax errors
3. Ensure all variable names match existing configuration
4. Run `terraform validate` before `terraform apply`
5. Check AWS permissions

### Issue: Service deployment fails
**Error**: Lambda alias creation fails

**Solution**:
1. Ensure infrastructure (API Gateway stage) is deployed first
2. Verify Lambda functions exist
3. Check that v3 alias doesn't already exist
4. Review Lambda permissions in Terraform

## Best Practices

### 1. Version Naming
- Use sequential version numbers: v1, v2, v3, v4...
- Don't skip version numbers
- Don't use v0 (reserved for development)

### 2. Status Progression
Follow this progression:
```
planned → alpha → beta → stable → deprecated → sunset
```

### 3. Migration Guides
- Update the template with actual changes
- Include real code examples
- Document all breaking changes
- Provide clear migration steps
- Test all examples before publishing

### 4. Infrastructure Changes
- Always review Terraform plan before applying
- Test in development environment first
- Keep infrastructure changes in version control
- Document any manual steps

### 5. Service Deployment
- Deploy all services together for consistency
- Test each endpoint after deployment
- Verify version headers
- Monitor for errors

### 6. Communication
- Announce new versions to API consumers
- Provide adequate migration time
- Document deprecation timeline
- Offer support during migration

## Related Workflows

- **Deploy API Version** (`.github/workflows/deploy-version.yml`)
  - Deploys services for a specific version
  - Use after adding new version

- **Deprecate API Version** (`.github/workflows/deprecate-version.yml`)
  - Marks a version as deprecated
  - Sets sunset date
  - Use when planning to remove a version

- **Sunset API Version** (`.github/workflows/sunset-version.yml`)
  - Removes a deprecated version
  - Updates documentation
  - Use when removing a version

## Example: Adding v3

Here's a complete example of adding version v3:

### 1. Run Workflow
```
Inputs:
  new_version: v3
  status: planned
  migration_guide_url: https://docs.iqq.com/api/migration
```

### 2. Review PRs (6 total)
- iqq-project: Merge ✅
- iqq-infrastructure: Review, don't merge yet
- iqq-package-service: Merge ✅
- iqq-lender-service: Merge ✅
- iqq-product-service: Merge ✅
- iqq-document-service: Merge ✅

### 3. Update Infrastructure
```bash
cd iqq-infrastructure
# Add stage, permissions, and output (see Step 3 above)
terraform apply
```

### 4. Deploy Services
```bash
# Via GitHub Actions UI
Workflow: Deploy API Version
Inputs:
  version: v3
  services: all
  environment: dev
```

### 5. Test
```bash
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

### 6. Update Migration Guide
```bash
cd iqq-project
# Edit docs/api/migrations/MIGRATION_v2_TO_v3.md
git add docs/api/migrations/MIGRATION_v2_TO_v3.md
git commit -m "docs: update v3 migration guide with actual changes"
git push
```

## Summary

The "Add New API Version" workflow automates most of the process of adding a new API version, but requires manual steps for infrastructure changes. This ensures safety and allows for review of critical infrastructure modifications.

**Automated**:
- ✅ Version validation
- ✅ Migration guide generation
- ✅ Configuration updates (6 repositories)
- ✅ Pull request creation
- ✅ Workflow updates

**Manual**:
- ⚠️ Infrastructure Terraform changes
- ⚠️ Terraform apply
- ⚠️ Migration guide content updates
- ⚠️ Testing and verification

**Time Estimate**:
- Workflow execution: 1-2 minutes
- PR reviews: 10-15 minutes
- Infrastructure updates: 15-20 minutes
- Service deployment: 15-20 minutes
- Testing: 10-15 minutes
- **Total**: ~1 hour

---

**Last Updated**: February 19, 2026  
**Workflow Version**: 1.0  
**Status**: Ready for use
