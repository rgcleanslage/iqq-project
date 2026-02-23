# Kiro Steering Files

This directory contains steering files that provide context and guidance for AI assistants working on the iQQ Insurance Quoting Platform.

## What are Steering Files?

Steering files are markdown documents that:
- Provide project-specific context and conventions
- Guide AI assistants on best practices
- Document architectural patterns and decisions
- Reference related documentation files
- Are automatically included in AI assistant context

## Available Steering Files

### 1. serverless-architecture.md
**Inclusion**: Auto (always included)

Covers serverless architecture patterns including:
- Lambda function standards (Node.js 20, ARM64, TypeScript)
- TypeScript build process (critical: pre-compile before SAM)
- Step Functions orchestration patterns
- DynamoDB single-table design
- SAM deployment practices
- Monitoring and logging
- Cost optimization strategies

**Key Topics**:
- Makefile-based builds for Lambda
- EXPRESS state machines for synchronous responses
- Map states for parallel processing
- Structured JSON logging with correlation IDs
- X-Ray tracing

### 2. authentication-authorization.md
**Inclusion**: Auto (always included)

Covers authentication and authorization including:
- Dual authentication model (OAuth + API keys)
- Custom TOKEN authorizer (not COGNITO_USER_POOLS)
- Cognito configuration and OAuth flows
- API key management and usage plans
- Request flow and error handling

**Key Topics**:
- Why TOKEN authorizer is required for client_credentials flow
- JWT token validation with JWKS
- API Gateway native API key validation
- Troubleshooting auth issues

### 3. deployment-practices.md
**Inclusion**: Auto (always included)

Covers deployment practices including:
- Hybrid deployment (Terraform + SAM)
- Deployment order (infrastructure → providers → services)
- TypeScript build process
- GitHub Actions CI/CD
- Rollback procedures
- Testing after deployment

**Key Topics**:
- Critical deployment order
- Pre-building TypeScript before SAM
- GitHub OIDC setup for CI/CD
- Common deployment issues and solutions

### 4. testing-practices.md
**Inclusion**: Auto (always included)

Covers testing practices including:
- Local Lambda testing with SAM
- Debugging with VS Code
- Unit testing with Jest
- Integration testing
- SoapUI testing
- Load testing

**Key Topics**:
- Why `sam local invoke` instead of `sam local start-api`
- Creating test events for API Gateway proxy format
- Debugging with source maps
- Monitoring during tests

### 5. project-conventions.md
**Inclusion**: Auto (always included)

Covers project conventions including:
- Naming conventions for AWS resources
- Code style guidelines
- Git conventions (branches, commits)
- Environment variables
- API conventions
- DynamoDB patterns
- Documentation standards

**Key Topics**:
- Resource naming patterns
- TypeScript style guide
- Structured logging format
- Error handling patterns
- Security guidelines

### 6. security-best-practices.md
**Inclusion**: Auto (always included)

Covers security best practices including:
- Secrets management (never commit to Git)
- Credential handling (use IAM roles, not access keys)
- Code security (input validation, error handling)
- AWS security (encryption, IAM, monitoring)
- Incident response procedures

**Key Topics**:
- AWS Secrets Manager for secrets
- GitHub Actions OIDC (not access keys)
- Never log tokens or sensitive data
- Encryption at rest and in transit
- CloudTrail and CloudWatch monitoring
- Security incident response

## Using Steering Files

### Automatic Inclusion

All steering files in this directory are set to `inclusion: auto`, meaning they are automatically included in the AI assistant's context when working on this project.

### File References

Steering files can reference other documentation using the special syntax:
```markdown
#[[file:docs/architecture/SYSTEM_ARCHITECTURE_DIAGRAM.md]]
```

This creates a link to related documentation that the AI can follow for more details.

## Project Information

- **AWS Account**: 785826687678
- **Region**: us-east-1
- **Environment**: dev
- **GitHub**: https://github.com/rgcleanslage/
- **API Gateway ID**: r8ukhidr1m
- **Cognito User Pool**: us-east-1_Wau5rEb2N

## Key Architecture Decisions

### 1. Custom TOKEN Authorizer
We use a custom TOKEN authorizer instead of COGNITO_USER_POOLS because:
- Client credentials flow returns access tokens (not ID tokens)
- COGNITO_USER_POOLS only validates ID tokens
- Custom authorizer validates access tokens using JWKS

### 2. Pre-compiled TypeScript
We pre-compile TypeScript before SAM build because:
- SAM's esbuild doesn't handle all TypeScript features
- Pre-building ensures consistent compilation
- Better error messages during development
- Faster builds

### 3. Hybrid Deployment
We use Terraform for infrastructure and SAM for Lambda because:
- Terraform manages resources that change infrequently
- SAM manages Lambda code that changes frequently
- Separation of concerns
- Better CI/CD workflows

### 4. Single-Table DynamoDB Design
We use single-table design because:
- Efficient queries with GSIs
- Lower cost (fewer tables)
- Better performance (fewer round trips)
- Flexible schema evolution

## Related Documentation

- [System Architecture Diagram](../../docs/architecture/SYSTEM_ARCHITECTURE_DIAGRAM.md)
- [Project Structure](../../docs/architecture/PROJECT_STRUCTURE.md)
- [Deployment Guide](../../docs/deployment/DEPLOYMENT_GUIDE.md)
- [API Documentation](../../docs/api/README.md)
- [Testing Guide](../../docs/testing/README.md)

## Updating Steering Files

When updating steering files:
1. Keep them focused and concise
2. Use clear examples
3. Reference related documentation
4. Update this README if adding new files
5. Test that file references work correctly

## Questions?

For questions about steering files or project conventions, refer to:
- [Documentation Index](../../DOCUMENTATION_INDEX.md)
- [Project README](../../README.md)
- Architecture documentation in `docs/architecture/`
