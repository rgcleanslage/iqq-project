# Implementation Plan: API Versioning

## Overview

Implement stage-based API versioning for the iQQ Insurance Quoting Platform using API Gateway stages (v1, v2) with centralized GitHub Actions orchestration from the root repository.

## Tasks

- [x] 1. Set up version control structure
  - Create release branches for version management
  - Set up centralized version policy configuration
  - _Requirements: AC-2.1, AC-2.2_
  - _Status: ✅ Complete - See docs/api/API_VERSIONING_SETUP.md_

- [x] 2. Update Terraform for stage-based versioning
  - [x] 2.1 Create v1 and v2 API Gateway stages
    - Modify `iqq-infrastructure/modules/api-gateway/main.tf`
    - Create `aws_api_gateway_stage` resources for v1 and v2
    - Configure stage variables (`lambdaAlias = "v1"` and `lambdaAlias = "v2"`)
    - Remove or update existing dev/prod stages
    - _Requirements: AC-1.1, AC-2.1_
    - _Status: ✅ Complete_
  
  - [x] 2.2 Update Lambda permissions for both stages
    - Add Lambda permissions for v1 stage
    - Add Lambda permissions for v2 stage
    - Update source ARNs to include stage names
    - _Requirements: AC-2.2_
    - _Status: ✅ Complete_
  
  - [x] 2.3 Update deployment configuration
    - Ensure single deployment is used for both stages
    - Configure deployment triggers
    - Test Terraform plan
    - _Requirements: AC-2.1_
    - _Status: ✅ Complete - See docs/deployment/API_VERSIONING_TERRAFORM.md_

- [x] 3. Implement Lambda version headers
  - [x] 3.1 Create response builder utility
    - Create `src/utils/response-builder.ts` in each service
    - Implement `buildVersionedResponse()` function
    - Add version header generation logic
    - _Requirements: AC-2.3, AC-3.2_
    - _Status: ✅ Complete_
  
  - [x] 3.2 Create version policy configuration
    - Create `config/version-policy.json` in each service
    - Define version metadata (status, sunset date, migration guide)
    - _Requirements: AC-2.3, AC-3.3_
    - _Status: ✅ Complete_
  
  - [x] 3.3 Update Lambda handlers to use response builder
    - Update package service handler
    - Update lender service handler
    - Update product service handler
    - Update document service handler
    - Extract version from `event.requestContext.stage`
    - _Requirements: AC-2.3_
    - _Status: ✅ Complete - All services deployed and tested_

- [x] 4. Set up centralized GitHub Actions workflows
  - [x] 4.1 Create root repository structure
    - Create `.github/workflows/` directory in root repo
    - Create `config/` directory for version policy
    - Create `scripts/` directory for helper scripts
    - _Requirements: AC-2.1_
    - _Status: ✅ Complete_
  
  - [x] 4.2 Implement centralized deployment workflow
    - Create `.github/workflows/deploy-version.yml` in root repo
    - Implement version validation job
    - Implement service deployment orchestration
    - Implement API Gateway update job
    - Implement verification job
    - _Requirements: AC-2.1, AC-2.2_
    - _Status: ✅ Complete - See docs/deployment/GITHUB_ACTIONS_VERSIONING.md_
  
  - [x] 4.3 Implement service deployment workflows
    - Create `.github/workflows/deploy.yml` in each service repo
    - Implement workflow_dispatch trigger
    - Implement Lambda deployment steps
    - Implement alias update logic
    - _Requirements: AC-2.2_
    - _Status: ✅ Complete - Template created in scripts/service-deploy-workflow.yml_
  
  - [x] 4.4 Implement deprecation workflow
    - Create `.github/workflows/deprecate-version.yml` in root repo
    - Implement version policy update logic
    - Implement configuration deployment
    - _Requirements: AC-2.3, AC-3.2_
    - _Status: ✅ Complete_
  
  - [x] 4.5 Implement sunset workflow
    - Create `.github/workflows/sunset-version.yml` in root repo
    - Implement validation and confirmation logic
    - Implement stage removal logic
    - Implement alias cleanup logic
    - _Requirements: AC-2.3_
    - _Status: ✅ Complete_

- [x] 5. Create release branches
  - [x] 5.1 Create v1 release branch
    - Create `release/v1` branch from main in each service repo
    - Push to remote
    - _Requirements: AC-2.1_
    - _Status: ✅ Complete - Branches created in all 5 repositories_
  
  - [x] 5.2 Create v2 release branch
    - Create `release/v2` branch from main in each service repo
    - Push to remote
    - _Requirements: AC-2.1_
    - _Status: ✅ Complete - Branches created in all 5 repositories_

- [ ] 6. Deploy initial versions
  - [ ] 6.1 Deploy v1 to Lambda
    - Trigger deployment workflow for v1
    - Verify Lambda alias v1 created
    - Verify version headers in responses
    - _Requirements: AC-1.1, AC-2.2_
  
  - [ ] 6.2 Deploy v2 to Lambda
    - Trigger deployment workflow for v2
    - Verify Lambda alias v2 created
    - Verify version headers in responses
    - _Requirements: AC-1.1, AC-2.2_
  
  - [ ] 6.3 Apply Terraform changes
    - Run `terraform plan` to review changes
    - Run `terraform apply` to create v1 and v2 stages
    - Verify stages created in API Gateway console
    - _Requirements: AC-1.1, AC-2.1_

- [ ] 7. Checkpoint - Verify versioned endpoints
  - Test v1 endpoints: `/v1/package`, `/v1/lender`, `/v1/product`, `/v1/document`
  - Test v2 endpoints: `/v2/package`, `/v2/lender`, `/v2/product`, `/v2/document`
  - Verify version headers in all responses
  - Verify concurrent access to both versions
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: AC-1.1, AC-2.1, AC-2.3_

- [ ] 8. Implement monitoring and logging
  - [ ] 8.1 Update CloudWatch log format
    - Update API Gateway access log format to include stage
    - Update Lambda logging to include version
    - _Requirements: AC-2.4, AC-3.1_
  
  - [ ] 8.2 Create CloudWatch dashboard
    - Create dashboard for version metrics
    - Add widgets for requests by version
    - Add widgets for error rates by version
    - Add widgets for latency by version
    - _Requirements: AC-2.4_
  
  - [ ]* 8.3 Set up CloudWatch alarms
    - Create alarm for high error rate on versioned endpoints
    - Create alarm for no requests to v2 (after launch)
    - Create alarm for continued high usage of deprecated version
    - _Requirements: AC-2.4_

- [ ] 9. Create documentation
  - [ ] 9.1 Update API reference documentation
    - Document versioning strategy
    - Document supported versions
    - Document version headers
    - Document version lifecycle
    - _Requirements: AC-4.1, AC-4.3_
  
  - [ ] 9.2 Create migration guide
    - Create `docs/api/MIGRATION_V1_TO_V2.md`
    - Document breaking changes
    - Provide code examples
    - Include testing recommendations
    - _Requirements: AC-4.2_
  
  - [ ] 9.3 Update OpenAPI specification
    - Create separate OpenAPI files for v1 and v2
    - Include version information in specs
    - Document version headers in response schemas
    - _Requirements: AC-4.3_
  
  - [ ] 9.4 Create changelog
    - Create `docs/api/CHANGELOG.md`
    - Document v1 and v2 releases
    - Document breaking changes
    - Document deprecation notices
    - _Requirements: AC-4.4_
  
  - [ ] 9.5 Update Postman collection
    - Create separate collections for v1 and v2
    - Update request URLs to use versioned stages
    - Add examples showing version headers
    - _Requirements: AC-4.1_

- [ ] 10. Testing and validation
  - [ ]* 10.1 Write integration tests for version routing
    - Test v1 stage routes to v1 Lambda alias
    - Test v2 stage routes to v2 Lambda alias
    - Test all service endpoints for both versions
    - _Requirements: AC-1.1, AC-2.2_
  
  - [ ]* 10.2 Write tests for version headers
    - Test version headers present in all responses
    - Test deprecation headers for deprecated versions
    - Test stable version headers
    - _Requirements: AC-2.3, AC-3.2_
  
  - [ ]* 10.3 Write tests for concurrent version access
    - Test simultaneous requests to v1 and v2
    - Verify no interference between versions
    - _Requirements: AC-2.1_
  
  - [ ]* 10.4 Write tests for GitHub Actions workflows
    - Test deployment workflow with mock triggers
    - Test deprecation workflow
    - Verify version policy updates
    - _Requirements: AC-2.1, AC-2.3_

- [ ] 11. Final checkpoint - End-to-end verification
  - Run full integration test suite
  - Verify all version endpoints accessible
  - Verify monitoring and logging working
  - Verify documentation complete and accurate
  - Test GitHub Actions workflows manually
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: All_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- GitHub Actions workflows are manual (workflow_dispatch) only
- Stage-based versioning: v1 and v2 are API Gateway stages, not URL paths
- Branch-based code management: release/v1 and release/v2 branches
- Centralized orchestration from root repository

## Deployment Order

1. Create release branches (Task 5)
2. Update Lambda functions with version headers (Task 3)
3. Deploy Lambda functions to v1 and v2 aliases (Task 6.1, 6.2)
4. Apply Terraform to create API Gateway stages (Task 6.3)
5. Set up GitHub Actions workflows (Task 4)
6. Verify and test (Tasks 7, 10, 11)
7. Create documentation (Task 9)
8. Set up monitoring (Task 8)

## Rollback Plan

If issues occur:
1. Revert Terraform changes to remove v1/v2 stages
2. Revert Lambda function changes
3. Keep release branches for future attempts
4. Document issues and lessons learned

