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

## 🚀 Deployment Documentation

### Deployment Guides
- **[docs/deployment/DEPLOYMENT_GUIDE.md](docs/deployment/DEPLOYMENT_GUIDE.md)** - Comprehensive deployment guide
- **[docs/deployment/HTTP_PROVIDER_MIGRATION.md](docs/deployment/HTTP_PROVIDER_MIGRATION.md)** - HTTP provider migration guide
- **[docs/deployment/HTTP_PROVIDER_MIGRATION_SUMMARY.md](docs/deployment/HTTP_PROVIDER_MIGRATION_SUMMARY.md)** - Migration summary

### Service Integration
- **[docs/deployment/PACKAGE_SERVICE_INTEGRATION.md](docs/deployment/PACKAGE_SERVICE_INTEGRATION.md)** - Package service integration guide
- **[docs/deployment/STEP_FUNCTIONS_INTEGRATION_COMPLETE.md](docs/deployment/STEP_FUNCTIONS_INTEGRATION_COMPLETE.md)** - Step Functions integration
- **[docs/deployment/STEP_FUNCTIONS_UPDATE.md](docs/deployment/STEP_FUNCTIONS_UPDATE.md)** - Step Functions updates

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
- **[scripts/test-api-endpoints.sh](scripts/test-api-endpoints.sh)** - API endpoint testing script
- **[scripts/run-all-tests.sh](scripts/run-all-tests.sh)** - Run all unit tests (bash)
- **[scripts/run-all-tests.js](scripts/run-all-tests.js)** - Run all unit tests (Node.js)
- **[docs/testing/test-all-endpoints.sh](docs/testing/test-all-endpoints.sh)** - Test all endpoints

## 📖 API Documentation

### API Specifications
- **[docs/api/OPENAPI_GUIDE.md](docs/api/OPENAPI_GUIDE.md)** - OpenAPI specification guide
- **[docs/api/openapi.yaml](docs/api/openapi.yaml)** - OpenAPI 3.0 specification
- **[docs/api/openapi-soapui.yaml](docs/api/openapi-soapui.yaml)** - SoapUI-compatible OpenAPI spec

### SoapUI Project
- **[docs/testing/iQQ-API-SoapUI-Project.xml](docs/testing/iQQ-API-SoapUI-Project.xml)** - SoapUI project file

## 🔧 Scripts & Tools

### Setup Scripts
- **[scripts/setup-env-from-terraform.sh](scripts/setup-env-from-terraform.sh)** - Extract credentials from Terraform
- **[scripts/create-and-push-all.sh](scripts/create-and-push-all.sh)** - GitHub CLI repository creation
- **[scripts/init-github-repos.sh](scripts/init-github-repos.sh)** - Manual GitHub initialization

### Utility Scripts
- **[scripts/seed-dynamodb.ts](scripts/seed-dynamodb.ts)** - Seed DynamoDB with provider data
- **[scripts/update-provider-urls.ts](scripts/update-provider-urls.ts)** - Update provider URLs from CloudFormation

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

- **Total Documentation Files:** 25 essential files
- **Root Documentation:** 3 files (README.md, REPOSITORIES.md, DOCUMENTATION_INDEX.md)
- **Architecture Docs:** 5 files
- **Deployment Docs:** 8 files
- **Testing Docs:** 4 files
- **API Docs:** 1 file
- **Repository READMEs:** 7 files
- **Scripts:** Multiple utility scripts

## 🔄 Recently Updated

- **DOCUMENTATION_INDEX.md** - Updated after final cleanup (removed 9 temporary status files)

---

**Last Updated:** February 16, 2026  
**Status:** Clean and organized - all temporary status files removed
