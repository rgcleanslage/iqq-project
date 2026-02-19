# How to Add a New API Version

This guide explains how to add a new version (e.g., v3) to the iQQ API platform.

## Overview

Adding a new version involves:
1. Updating version policy configuration
2. Creating API Gateway stage in Terraform
3. Updating service version policies
4. Creating Lambda aliases
5. Deploying and testing
6. Generating migration guide (automated)

## Automated Workflow

You can automate most of these steps using the "Add New API Version" workflow:

1. Go to: https://github.com/rgcleanslage/iqq-project/actions
2. Click "Add New API Version"
3. Click "Run workflow"
4. Enter:
   - **new_version**: `v3` (or desired version)
   - **status**: `planned`, `alpha`, or `beta`
   - **migration_guide_url**: Optional URL
5. Click "Run workflow"

This will automatically:
- Create PRs in all 6 repositories
- Update version policies
- Generate migration guide template
- Provide Terraform configuration
- Create deployment instructions

After the workflow completes, you can generate a detailed migration guide by running the "Generate Migration Guide from Code Changes" workflow.

## Step-by-Step Guide

### Step 1: Update Root Version Policy

Edit `config/version-policy.json` in the root repository:

```json
{
  "currentVersion": "v2",
  "versions": {
    "v1": {
      "status": "stable",
      "sunsetDate": null,
      "migrationGuide": null
    },
    "v2": {
      "status": "stable",
      "sunsetDate": null,
      "migrationGuide": null
    },
    "v3": {
      "status": "planned",
      "sunsetDate": null,
      "migrationGuide": "https://docs.iqq.com/api/migration/v2-to-v3"
    }
  }
}
```

**Commit and push:**
```bash
git add config/version-policy.json
git commit -m "feat: add v3 to version policy"
git push origin main
```

### Step 2: Update Terraform for New Stage

Edit `iqq-infrastructure/modules/api-gateway/main.tf`:

Add the new stage resource:

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

Add Lambda permissions for v3 stage (for each service):

```hcl
# Package service v3 permission
resource "aws_lambda_permission" "package_v3" {
  statement_id  = "AllowAPIGatewayInvokeV3"
  function_name = var.package_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/v3/GET/package"
  qualifier     = "v3"
}

# Lender service v3 permission
resource "aws_lambda_permission" "lender_v3" {
  statement_id  = "AllowAPIGatewayInvokeV3"
  function_name = var.lender_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/v3/GET/lender"
  qualifier     = "v3"
}

# Product service v3 permission
resource "aws_lambda_permission" "product_v3" {
  statement_id  = "AllowAPIGatewayInvokeV3"
  function_name = var.product_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/v3/GET/product"
  qualifier     = "v3"
}

# Document service v3 permission
resource "aws_lambda_permission" "document_v3" {
  statement_id  = "AllowAPIGatewayInvokeV3"
  function_name = var.document_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/v3/GET/document"
  qualifier     = "v3"
}
```

Update outputs in `iqq-infrastructure/modules/api-gateway/outputs.tf`:

```hcl
output "v3_stage_url" {
  description = "URL for v3 stage"
  value       = "${aws_api_gateway_stage.v3.invoke_url}"
}
```

**Deploy Terraform changes:**
```bash
cd iqq-infrastructure
terraform plan
terraform apply
```

### Step 3: Update Service Version Policies

For each service (package, lender, product, document), update `src/config/version-policy.json`:

```json
{
  "currentVersion": "v2",
  "versions": {
    "v1": {
      "status": "stable",
      "sunsetDate": null,
      "migrationGuide": null
    },
    "v2": {
      "status": "stable",
      "sunsetDate": null,
      "migrationGuide": null
    },
    "v3": {
      "status": "planned",
      "sunsetDate": null,
      "migrationGuide": "https://docs.iqq.com/api/migration/v2-to-v3"
    }
  }
}
```

**For each service:**
```bash
cd iqq-package-service
git add src/config/version-policy.json
git commit -m "feat: add v3 to version policy"
git push origin main

# Repeat for lender, product, document services
```

### Step 4: Update Workflow Choices

Edit `.github/workflows/deploy-version.yml` in root repository:

```yaml
version:
  description: 'Version to deploy (v1, v2, v3)'
  required: true
  type: choice
  options:
    - v1
    - v2
    - v3  # Add this
```

Do the same for:
- `.github/workflows/deprecate-version.yml`
- `.github/workflows/sunset-version.yml`

**Commit and push:**
```bash
git add .github/workflows/
git commit -m "feat: add v3 to workflow options"
git push origin main
```

### Step 5: Deploy v3 to All Services

Use the GitHub Actions workflow:

1. Go to: https://github.com/rgcleanslage/iqq-project/actions
2. Click "Deploy API Version"
3. Click "Run workflow"
4. Select:
   - **version**: `v3`
   - **services**: `all`
   - **environment**: `dev`
5. Click "Run workflow"

This will:
- Deploy all 4 services
- Create v3 Lambda aliases
- Verify deployments
- Update version policy

### Step 6: Verify New Version

Test the new v3 endpoints:

```bash
# Get OAuth token
cd iqq-infrastructure
CLIENT_ID=$(terraform output -json cognito_partner_clients | jq -r '.default.client_id')
CLIENT_SECRET=$(terraform output -json cognito_partner_client_secrets | jq -r '.default')
API_KEY=$(terraform output -raw default_api_key_value)

TOKEN=$(curl -s -X POST "https://iqq-dev-ib9i1hvt.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Test v3 endpoints
curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/package?productCode=MBP" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/lender?lenderId=LENDER-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/product?productId=PROD-001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"

curl -i "https://r8ukhidr1m.execute-api.us-east-1.amazonaws.com/v3/document" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-api-key: $API_KEY"
```

Verify version headers:
```bash
# Should see:
# x-api-version: v3
# x-api-deprecated: false
# x-api-sunset-date: null
```

### Step 7: Promote to Current (Optional)

When v3 is ready to be the current version, update `config/version-policy.json`:

```json
{
  "currentVersion": "v3",  // Changed from v2
  "versions": {
    "v1": {
      "status": "stable",
      "sunsetDate": null,
      "migrationGuide": null
    },
    "v2": {
      "status": "stable",
      "sunsetDate": null,
      "migrationGuide": null
    },
    "v3": {
      "status": "stable",  // Changed from planned
      "sunsetDate": null,
      "migrationGuide": null
    }
  }
}
```

## Quick Reference

### Files to Update

1. **Root Repository**:
   - `config/version-policy.json` - Add new version
   - `.github/workflows/deploy-version.yml` - Add to choices
   - `.github/workflows/deprecate-version.yml` - Add to choices
   - `.github/workflows/sunset-version.yml` - Add to choices

2. **Infrastructure Repository**:
   - `modules/api-gateway/main.tf` - Add stage and permissions
   - `modules/api-gateway/outputs.tf` - Add stage URL output

3. **Service Repositories** (all 4):
   - `src/config/version-policy.json` - Add new version

### Version Statuses

- `planned` - Version defined but not yet released
- `alpha` - Internal testing only
- `beta` - Selected partners
- `stable` - Production-ready
- `deprecated` - Scheduled for removal
- `sunset` - No longer supported

### Deployment Order

1. ✅ Update version policies (root + services)
2. ✅ Update Terraform (infrastructure)
3. ✅ Deploy Terraform changes
4. ✅ Update workflow choices
5. ✅ Deploy services via GitHub Actions
6. ✅ Verify endpoints
7. ✅ Promote to current (when ready)

## Rollback

If you need to remove a version:

1. Use the "Sunset API Version" workflow
2. Or manually:
   ```bash
   # Remove API Gateway stage
   aws apigateway delete-stage \
     --rest-api-id r8ukhidr1m \
     --stage-name v3
   
   # Remove Lambda aliases
   for service in package lender product document; do
     aws lambda delete-alias \
       --function-name iqq-${service}-service-dev \
       --name v3
   done
   ```

## Best Practices

1. **Start with "planned" status** - Don't make it current immediately
2. **Test thoroughly** - Verify all endpoints before promoting
3. **Document breaking changes** - Create migration guide
4. **Communicate early** - Notify API consumers about new version
5. **Monitor adoption** - Track usage of new version
6. **Deprecate old versions** - Give 90+ days notice before sunset

## Automated Migration Guide Generation

After adding a new version, you can automatically generate a migration guide based on code analysis:

### Using the Generate Migration Guide Workflow

1. Go to: https://github.com/rgcleanslage/iqq-project/actions
2. Click "Generate Migration Guide from Code Changes"
3. Click "Run workflow"
4. Enter:
   - **from_version**: `v2` (source version)
   - **to_version**: `v3` (target version)
   - **analyze_services**: `all` (or comma-separated list)
5. Click "Run workflow"

This workflow will:
- Analyze code changes across all services
- Extract handler signatures and data models
- Compare dependencies between versions
- Generate comprehensive migration guide
- Create PR with auto-generated documentation

The generated guide includes:
- Detected code changes by service
- Handler signature comparisons
- Data model changes
- Dependency updates
- Migration steps with code examples
- Testing instructions
- Rollback plan

After the workflow completes, review the PR and enhance the guide with:
- Specific breaking change descriptions
- Behavioral differences
- Timeline information
- Customer-facing examples

## Related Documentation

- [API Versioning Setup](../api/API_VERSIONING_SETUP.md)
- [GitHub Actions Versioning](./GITHUB_ACTIONS_VERSIONING.md)
- [Terraform Implementation](./API_VERSIONING_TERRAFORM.md)

## Workflows Available

1. **Add New API Version** - Automates version creation across all repositories
2. **Generate Migration Guide from Code Changes** - Analyzes code and generates migration docs
3. **Deploy API Version** - Deploys services to specific version
4. **Deprecate API Version** - Marks version as deprecated
5. **Sunset API Version** - Removes version from API Gateway

---

**Last Updated**: February 18, 2026
