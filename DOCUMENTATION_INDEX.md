# Documentation Index

Complete index of all documentation for the iQQ Insurance Quoting Platform.

## 📦 Repository Documentation

### Main README
- **[README.md](README.md)** - Project overview, quick start, architecture

### Repository Management
- **[REPOSITORIES.md](REPOSITORIES.md)** - All 6 GitHub repositories with links and descriptions

## 🏗️ Architecture Documentation

### System Architecture
- **[docs/architecture/SYSTEM_ARCHITECTURE_DIAGRAM.md](docs/architecture/SYSTEM_ARCHITECTURE_DIAGRAM.md)** - Complete system architecture with diagrams
- **[docs/architecture/ARCHITECTURE_VISUAL.md](docs/architecture/ARCHITECTURE_VISUAL.md)** - Visual architecture representations
- **[docs/architecture/PROJECT_STRUCTURE.md](docs/architecture/PROJECT_STRUCTURE.md)** - Project structure and organization

### Component Architecture
- **[docs/architecture/ADAPTER_ARCHITECTURE.md](docs/architecture/ADAPTER_ARCHITECTURE.md)** - CSV/XML adapter design and implementation
- **[docs/architecture/PATH_BASED_ACCESS_CONTROL_GUIDE.md](docs/architecture/PATH_BASED_ACCESS_CONTROL_GUIDE.md)** - Path-based access control implementation

### Client Preferences
- **[docs/architecture/CLIENT_PREFERENCES_README.md](docs/architecture/CLIENT_PREFERENCES_README.md)** - Quick start guide for client preferences
- **[docs/architecture/CLIENT_PREFERENCES_GUIDE.md](docs/architecture/CLIENT_PREFERENCES_GUIDE.md)** - Complete client preferences documentation
- **[docs/architecture/CLIENT_PREFERENCES_IMPLEMENTATION.md](docs/architecture/CLIENT_PREFERENCES_IMPLEMENTATION.md)** - Implementation details and summary

## 🚀 Deployment Documentation

### Deployment Guides
- **[docs/deployment/DEPLOYMENT_GUIDE.md](docs/deployment/DEPLOYMENT_GUIDE.md)** - Comprehensive deployment guide
- **[docs/deployment/HTTP_PROVIDER_MIGRATION.md](docs/deployment/HTTP_PROVIDER_MIGRATION.md)** - HTTP provider migration guide
- **[docs/deployment/HTTP_PROVIDER_MIGRATION_SUMMARY.md](docs/deployment/HTTP_PROVIDER_MIGRATION_SUMMARY.md)** - Migration summary

### Service Integration
- **[docs/deployment/PACKAGE_SERVICE_INTEGRATION.md](docs/deployment/PACKAGE_SERVICE_INTEGRATION.md)** - Package service integration guide
- **[docs/deployment/STEP_FUNCTIONS_INTEGRATION_COMPLETE.md](docs/deployment/STEP_FUNCTIONS_INTEGRATION_COMPLETE.md)** - Step Functions integration
- **[docs/deployment/STEP_FUNCTIONS_FIX_COMPLETE.md](docs/deployment/STEP_FUNCTIONS_FIX_COMPLETE.md)** - Step Functions Lambda ARN fix
- **[docs/deployment/STEP_FUNCTIONS_UPDATE.md](docs/deployment/STEP_FUNCTIONS_UPDATE.md)** - Step Functions updates

### Authorization
- **[docs/deployment/AUTHORIZER_CLEANUP_COMPLETE.md](docs/deployment/AUTHORIZER_CLEANUP_COMPLETE.md)** - Custom TOKEN authorizer implementation
- **[docs/deployment/COGNITO_AUTHORIZER_ISSUE.md](docs/deployment/COGNITO_AUTHORIZER_ISSUE.md)** - Cognito authorizer migration notes

### Security & API Keys
- **[docs/deployment/API_KEY_DEPLOYMENT_GUIDE.md](docs/deployment/API_KEY_DEPLOYMENT_GUIDE.md)** - API key deployment guide
- **[docs/deployment/API_KEY_BEHAVIOR.md](docs/deployment/API_KEY_BEHAVIOR.md)** - API key behavior documentation

## 🧪 Testing Documentation

### Test Results
- **[docs/testing/HTTP_PROVIDER_TEST_RESULTS.md](docs/testing/HTTP_PROVIDER_TEST_RESULTS.md)** - API endpoint test results
- **[docs/testing/COVERAGE_IMPROVEMENT_SUMMARY.md](docs/testing/COVERAGE_IMPROVEMENT_SUMMARY.md)** - Test coverage improvements

### Testing Guides
- **[docs/testing/SOAPUI_TESTING_GUIDE.md](docs/testing/SOAPUI_TESTING_GUIDE.md)** - SoapUI testing guide
- **[docs/testing/SOAPUI_QUICK_START.md](docs/testing/SOAPUI_QUICK_START.md)** - SoapUI quick start

### Test Scripts
- **[scripts/test-api-complete.sh](scripts/test-api-complete.sh)** - Complete API testing with OAuth
- **[scripts/test-all-clients.sh](scripts/test-all-clients.sh)** - Test all OAuth clients
- **[scripts/test-client-preferences.sh](scripts/test-client-preferences.sh)** - Test client preferences filtering
- **[docs/testing/test-all-endpoints.sh](docs/testing/test-all-endpoints.sh)** - Test all endpoints

## 📖 API Documentation

### API Specifications
- **[docs/api/README.md](docs/api/README.md)** - API documentation overview
- **[docs/api/openapi-complete.yaml](docs/api/openapi-complete.yaml)** - Complete OpenAPI 3.0.3 specification with OAuth
- **[docs/api/OPENAPI_USAGE_GUIDE.md](docs/api/OPENAPI_USAGE_GUIDE.md)** - How to use the OpenAPI specification
- **[docs/api/API_DOCUMENTATION_COMPLETE.md](docs/api/API_DOCUMENTATION_COMPLETE.md)** - Complete API documentation

### OAuth & Authentication
- **[docs/api/CLIENT_CREDENTIALS_MAPPING.md](docs/api/CLIENT_CREDENTIALS_MAPPING.md)** - Cognito client to API key mapping
- **[docs/api/MULTIPLE_CLIENTS_COMPLETE.md](docs/api/MULTIPLE_CLIENTS_COMPLETE.md)** - Multiple OAuth clients setup

### Postman Collections
- **[docs/api/postman-collection-fixed.json](docs/api/postman-collection-fixed.json)** - Fixed Postman collection with OAuth
- **[docs/api/POSTMAN_STEP_BY_STEP.md](docs/api/POSTMAN_STEP_BY_STEP.md)** - Step-by-step Postman setup
- **[docs/api/POSTMAN_QUICK_FIX.md](docs/api/POSTMAN_QUICK_FIX.md)** - Quick fix for Postman OAuth issues
- **[docs/api/POSTMAN_TROUBLESHOOTING.md](docs/api/POSTMAN_TROUBLESHOOTING.md)** - Postman troubleshooting guide
- **[docs/api/credential-encoder.html](docs/api/credential-encoder.html)** - OAuth credential encoder tool

### Postman Environments
- **[docs/api/postman-environment-default.json](docs/api/postman-environment-default.json)** - Default client environment
- **[docs/api/postman-environment-partner-a.json](docs/api/postman-environment-partner-a.json)** - Partner A environment
- **[docs/api/postman-environment-partner-b.json](docs/api/postman-environment-partner-b.json)** - Partner B environment

### SoapUI Project
- **[docs/testing/iQQ-API-SoapUI-Project.xml](docs/testing/iQQ-API-SoapUI-Project.xml)** - SoapUI project file

## 🔧 Scripts & Tools

### Setup Scripts
- **[scripts/setup-env-from-terraform.sh](scripts/setup-env-from-terraform.sh)** - Extract credentials from Terraform
- **[scripts/create-and-push-all.sh](scripts/create-and-push-all.sh)** - GitHub CLI repository creation
- **[scripts/init-github-repos.sh](scripts/init-github-repos.sh)** - Manual GitHub initialization

### Data Management Scripts
- **[scripts/seed-dynamodb.ts](scripts/seed-dynamodb.ts)** - Seed DynamoDB with provider data
- **[scripts/update-provider-urls.ts](scripts/update-provider-urls.ts)** - Update provider URLs from CloudFormation
- **[scripts/manage-client-preferences.ts](scripts/manage-client-preferences.ts)** - Manage client preferences (set/get/delete)

## 📝 Status & Summary Documents

This section has been removed - all status documents were temporary and have been cleaned up.

## 📂 Repository-Specific Documentation

### iqq-infrastructure
- **[iqq-infrastructure/README.md](iqq-infrastructure/README.md)** - Infrastructure deployment guide
- Terraform modules documentation in each module directory

### iqq-providers
- **[iqq-providers/README.md](iqq-providers/README.md)** - Provider services overview
- Individual provider READMEs in each provider directory

### Microservices
- **[iqq-lender-service/README.md](iqq-lender-service/README.md)** - Lender service documentation
- **[iqq-package-service/README.md](iqq-package-service/README.md)** - Package service documentation
- **[iqq-product-service/README.md](iqq-product-service/README.md)** - Product service documentation
- **[iqq-document-service/README.md](iqq-document-service/README.md)** - Document service documentation

## 🔍 Quick Reference

### For New Users
1. Start with [README.md](README.md)
2. Review [REPOSITORIES.md](REPOSITORIES.md)
3. Follow [docs/deployment/DEPLOYMENT_GUIDE.md](docs/deployment/DEPLOYMENT_GUIDE.md)

### For Deployment
1. [docs/deployment/DEPLOYMENT_GUIDE.md](docs/deployment/DEPLOYMENT_GUIDE.md) - Main guide
2. [scripts/setup-env-from-terraform.sh](scripts/setup-env-from-terraform.sh) - Setup credentials
3. [scripts/test-api-endpoints.sh](scripts/test-api-endpoints.sh) - Test deployment

### For Testing
1. [docs/testing/HTTP_PROVIDER_TEST_RESULTS.md](docs/testing/HTTP_PROVIDER_TEST_RESULTS.md) - Test results
2. [docs/testing/COVERAGE_IMPROVEMENT_SUMMARY.md](docs/testing/COVERAGE_IMPROVEMENT_SUMMARY.md) - Coverage report
3. [scripts/test-api-endpoints.sh](scripts/test-api-endpoints.sh) - Run API tests

### For Architecture Understanding
1. [docs/architecture/SYSTEM_ARCHITECTURE_DIAGRAM.md](docs/architecture/SYSTEM_ARCHITECTURE_DIAGRAM.md) - System overview
2. [docs/architecture/ADAPTER_ARCHITECTURE.md](docs/architecture/ADAPTER_ARCHITECTURE.md) - Adapter design
3. [docs/architecture/PROJECT_STRUCTURE.md](docs/architecture/PROJECT_STRUCTURE.md) - Project structure

### For Security
1. [docs/deployment/API_KEY_DEPLOYMENT_GUIDE.md](docs/deployment/API_KEY_DEPLOYMENT_GUIDE.md) - API key setup
2. [scripts/setup-env-from-terraform.sh](scripts/setup-env-from-terraform.sh) - Credential management

## 📊 Documentation Statistics

- **Total Documentation Files:** 45+ essential files
- **Root Documentation:** 3 files (README.md, REPOSITORIES.md, DOCUMENTATION_INDEX.md)
- **Architecture Docs:** 8 files (including client preferences)
- **Deployment Docs:** 12 files
- **Testing Docs:** 4 files
- **API Docs:** 14 files (OpenAPI, Postman, OAuth guides)
- **Repository READMEs:** 7 files
- **Scripts:** Multiple utility and management scripts

## 🔄 Recently Updated

- **Client Preferences System** - Complete implementation with single-table design
- **Provider Filtering** - Dynamic provider filtering based on client preferences
- **Management Scripts** - CLI tools for managing client preferences
- **OAuth Implementation** - Complete OAuth 2.0 with multiple Cognito clients
- **Custom TOKEN Authorizer** - Migrated from COGNITO_USER_POOLS to custom authorizer
- **Step Functions Fix** - Fixed Lambda ARN issue in orchestration
- **Postman Collections** - Fixed OAuth authentication issues
- **API Documentation** - Complete OpenAPI 3.0.3 specification with OAuth endpoint

---

**Last Updated:** February 18, 2026  
**Status:** Production ready with OAuth 2.0 and client preferences ✅
