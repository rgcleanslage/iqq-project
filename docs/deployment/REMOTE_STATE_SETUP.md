# Remote State Management for Team Collaboration

This document explains how Terraform and SAM state management is configured for team collaboration.

## Overview

For team collaboration, we use remote state storage to ensure:
- Multiple team members can work on infrastructure without conflicts
- State is versioned and backed up
- State locking prevents concurrent modifications
- Consistent deployments across environments

## Infrastructure

### Terraform State

**S3 Bucket**: `iqq-terraform-state-785826687678`
- Versioning: Enabled
- Encryption: AES256
- Public Access: Blocked
- Lifecycle: Old versions deleted after 90 days

**DynamoDB Table**: `iqq-terraform-locks`
- Purpose: State locking to prevent concurrent modifications
- Billing: Pay-per-request

**Backend Configuration** (in `iqq-infrastructure/main.tf`):
```hcl
backend "s3" {
  bucket         = "iqq-terraform-state-785826687678"
  key            = "infrastructure/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "iqq-terraform-locks"
  encrypt        = true
}
```

### SAM Deployment Artifacts

**S3 Bucket**: `iqq-sam-deployments-785826687678`
- Versioning: Enabled
- Encryption: AES256
- Public Access: Blocked
- Lifecycle: Artifacts deleted after 30 days, old versions after 7 days

All SAM services use this shared bucket with different prefixes:
- `iqq-providers/` - Provider service artifacts
- `iqq-lender-service-dev/` - Lender service artifacts
- `iqq-package-service-dev/` - Package service artifacts
- `iqq-product-service-dev/` - Product service artifacts
- `iqq-document-service-dev/` - Document service artifacts

## Setup for New Team Members

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- SAM CLI installed
- Access to the AWS account (785826687678)

### Initial Setup

1. **Clone the repositories**:
```bash
git clone https://github.com/rgcleanslage/iqq-infrastructure.git
git clone https://github.com/rgcleanslage/iqq-providers.git
# ... clone other repositories
```

2. **Initialize Terraform** (downloads remote state):
```bash
cd iqq-infrastructure
terraform init
```

The remote state will be automatically downloaded from S3.

3. **Verify state**:
```bash
terraform show
```

### Working with Terraform

#### Making Changes

1. Create a feature branch:
```bash
git checkout -b feature/my-change
```

2. Make your changes to `.tf` files

3. Plan your changes:
```bash
terraform plan -var="environment=dev"
```

4. If working locally, apply changes:
```bash
terraform apply -var="environment=dev"
```

5. Commit and push:
```bash
git add .
git commit -m "feat: description of change"
git push origin feature/my-change
```

6. Create a pull request to `develop` branch

#### State Locking

Terraform automatically locks the state when running operations:
- `terraform plan` - Read lock
- `terraform apply` - Write lock
- `terraform destroy` - Write lock

If someone else is running an operation, you'll see:
```
Error: Error acquiring the state lock
```

Wait for them to finish, or if the lock is stale (process crashed), you can force unlock:
```bash
terraform force-unlock <LOCK_ID>
```

### Working with SAM

#### Local Development

Each SAM service has a `samconfig.toml` file (gitignored) that you can customize locally:

```toml
version = 0.1

[default.deploy.parameters]
stack_name = "iqq-lender-service-dev"
s3_bucket = "iqq-sam-deployments-785826687678"
s3_prefix = "iqq-lender-service-dev"
region = "us-east-1"
capabilities = "CAPABILITY_IAM"
```

#### Deploying Locally

```bash
cd iqq-lender-service
sam build
sam deploy
```

SAM will upload artifacts to the shared S3 bucket and deploy via CloudFormation.

#### CI/CD Deployments

GitHub Actions workflows automatically deploy when you push to:
- `develop` branch → Deploys to dev environment
- `main` branch → Deploys to prod environment

The workflows use the `SAM_DEPLOYMENT_BUCKET` secret which is set to `iqq-sam-deployments-785826687678`.

## GitHub Secrets

All repositories have these secrets configured:

| Secret | Value | Purpose |
|--------|-------|---------|
| `AWS_ROLE_ARN` | `arn:aws:iam::785826687678:role/github-actions-sam-dev` (SAM repos) or `arn:aws:iam::785826687678:role/github-actions-terraform-dev` (infrastructure) | OIDC role for AWS authentication |
| `SAM_DEPLOYMENT_BUCKET` | `iqq-sam-deployments-785826687678` | S3 bucket for SAM artifacts |

## Troubleshooting

### "Backend initialization required"

If you see this error:
```
Error: Backend initialization required
```

Run:
```bash
terraform init
```

### "State lock timeout"

If someone's process crashed and left a stale lock:

1. Get the lock ID from the error message
2. Force unlock:
```bash
terraform force-unlock <LOCK_ID>
```

### "Access Denied" to S3 bucket

Ensure your AWS credentials have permissions to:
- Read/write to `iqq-terraform-state-785826687678`
- Read/write to `iqq-sam-deployments-785826687678`
- Read/write to `iqq-terraform-locks` DynamoDB table

### SAM deployment fails with "bucket does not exist"

The bucket exists but you may need to specify it explicitly:
```bash
sam deploy --s3-bucket iqq-sam-deployments-785826687678
```

Or update your local `samconfig.toml` file.

## Maintenance

### Viewing Terraform State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.api_gateway.aws_api_gateway_rest_api.main

# Pull current state
terraform state pull > state.json
```

### Cleaning Up Old SAM Artifacts

The S3 bucket has lifecycle policies that automatically:
- Delete artifacts older than 30 days
- Delete old versions after 7 days

To manually clean up:
```bash
aws s3 rm s3://iqq-sam-deployments-785826687678/iqq-lender-service-dev/ --recursive
```

### Backing Up State

Terraform state is automatically versioned in S3. To download a backup:

```bash
aws s3 cp s3://iqq-terraform-state-785826687678/infrastructure/terraform.tfstate ./backup-state.json
```

To restore from a specific version:
```bash
aws s3api list-object-versions --bucket iqq-terraform-state-785826687678 --prefix infrastructure/terraform.tfstate
aws s3api get-object --bucket iqq-terraform-state-785826687678 --key infrastructure/terraform.tfstate --version-id <VERSION_ID> ./restore-state.json
```

## Security Best Practices

1. **Never commit state files** - They contain sensitive data
2. **Use OIDC for CI/CD** - No long-lived credentials
3. **Enable MFA for AWS console** - Protect against unauthorized access
4. **Review Terraform plans** - Always review before applying
5. **Use branch protection** - Require PR reviews for main/develop
6. **Rotate credentials** - If access keys are compromised
7. **Monitor CloudTrail** - Track who made what changes

## Re-creating Infrastructure

If you need to recreate the remote state infrastructure:

```bash
./scripts/setup-remote-state.sh
```

This script creates:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- S3 bucket for SAM deployments

All with proper security settings (encryption, versioning, public access blocking).

## Additional Resources

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [SAM Deployment Documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-deploying.html)
- [GitHub OIDC Setup Guide](./GITHUB_OIDC_SETUP.md)

---

**Last Updated**: February 16, 2026  
**Maintained By**: DevOps Team
