#!/bin/bash

# iQQ Test Runner - Executes all tests and aggregates results
# Usage: ./scripts/run-all-tests.sh [--coverage] [--verbose]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
COVERAGE=false
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --coverage)
      COVERAGE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      echo "Usage: ./scripts/run-all-tests.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --coverage    Generate coverage reports"
      echo "  --verbose     Show detailed test output"
      echo "  --help        Show this help message"
      exit 0
      ;;
  esac
done

# Test results tracking
TOTAL_SERVICES=0
PASSED_SERVICES=0
FAILED_SERVICES=0
SKIPPED_SERVICES=0

declare -a FAILED_SERVICE_NAMES=()
declare -a TEST_RESULTS=()

# Function to print section header
print_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

# Function to run tests for a service
run_service_tests() {
  local service_name=$1
  local service_path=$2
  
  TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
  
  echo -e "${YELLOW}Testing: ${service_name}${NC}"
  echo "Path: ${service_path}"
  
  # Check if service directory exists
  if [ ! -d "$service_path" ]; then
    echo -e "${RED}✗ Directory not found${NC}"
    SKIPPED_SERVICES=$((SKIPPED_SERVICES + 1))
    TEST_RESULTS+=("${service_name}|SKIPPED|Directory not found")
    return
  fi
  
  # Check if package.json exists
  if [ ! -f "$service_path/package.json" ]; then
    echo -e "${RED}✗ No package.json found${NC}"
    SKIPPED_SERVICES=$((SKIPPED_SERVICES + 1))
    TEST_RESULTS+=("${service_name}|SKIPPED|No package.json")
    return
  fi
  
  # Check if node_modules exists, install if not
  if [ ! -d "$service_path/node_modules" ]; then
    echo "Installing dependencies..."
    if [ "$VERBOSE" = true ]; then
      (cd "$service_path" && npm install)
    else
      (cd "$service_path" && npm install > /dev/null 2>&1)
    fi
  fi
  
  # Run tests
  local test_cmd="npm test"
  if [ "$COVERAGE" = true ]; then
    test_cmd="npm run test:coverage"
  fi
  
  if [ "$VERBOSE" = true ]; then
    if (cd "$service_path" && eval "$test_cmd"); then
      echo -e "${GREEN}✓ Tests passed${NC}"
      PASSED_SERVICES=$((PASSED_SERVICES + 1))
      TEST_RESULTS+=("${service_name}|PASSED|All tests passed")
    else
      echo -e "${RED}✗ Tests failed${NC}"
      FAILED_SERVICES=$((FAILED_SERVICES + 1))
      FAILED_SERVICE_NAMES+=("$service_name")
      TEST_RESULTS+=("${service_name}|FAILED|Test execution failed")
    fi
  else
    if (cd "$service_path" && eval "$test_cmd" > /dev/null 2>&1); then
      echo -e "${GREEN}✓ Tests passed${NC}"
      PASSED_SERVICES=$((PASSED_SERVICES + 1))
      TEST_RESULTS+=("${service_name}|PASSED|All tests passed")
    else
      echo -e "${RED}✗ Tests failed${NC}"
      FAILED_SERVICES=$((FAILED_SERVICES + 1))
      FAILED_SERVICE_NAMES+=("$service_name")
      TEST_RESULTS+=("${service_name}|FAILED|Test execution failed")
    fi
  fi
  
  echo ""
}

# Main execution
print_header "iQQ Test Suite Runner"

echo "Configuration:"
echo "  Coverage: $COVERAGE"
echo "  Verbose: $VERBOSE"
echo ""

START_TIME=$(date +%s)

# Run tests for each service
print_header "Running Tests"

run_service_tests "Provider Services" "iqq-providers"
run_service_tests "Package Service" "iqq-package-service"
run_service_tests "Lender Service" "iqq-lender-service"
run_service_tests "Product Service" "iqq-product-service"
run_service_tests "Document Service" "iqq-document-service"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Print summary
print_header "Test Results Summary"

echo -e "${BLUE}Service Results:${NC}"
echo ""
printf "%-30s %-10s %-30s\n" "Service" "Status" "Details"
printf "%-30s %-10s %-30s\n" "-------" "------" "-------"

for result in "${TEST_RESULTS[@]}"; do
  IFS='|' read -r service status details <<< "$result"
  
  case $status in
    PASSED)
      printf "%-30s ${GREEN}%-10s${NC} %-30s\n" "$service" "$status" "$details"
      ;;
    FAILED)
      printf "%-30s ${RED}%-10s${NC} %-30s\n" "$service" "$status" "$details"
      ;;
    SKIPPED)
      printf "%-30s ${YELLOW}%-10s${NC} %-30s\n" "$service" "$status" "$details"
      ;;
  esac
done

echo ""
echo -e "${BLUE}Statistics:${NC}"
echo "  Total Services: $TOTAL_SERVICES"
echo -e "  ${GREEN}Passed: $PASSED_SERVICES${NC}"
echo -e "  ${RED}Failed: $FAILED_SERVICES${NC}"
echo -e "  ${YELLOW}Skipped: $SKIPPED_SERVICES${NC}"
echo "  Duration: ${DURATION}s"

# Coverage report locations
if [ "$COVERAGE" = true ]; then
  echo ""
  echo -e "${BLUE}Coverage Reports:${NC}"
  
  if [ -d "iqq-providers/coverage" ]; then
    echo "  Provider Services: iqq-providers/coverage/index.html"
  fi
  
  if [ -d "iqq-package-service/coverage" ]; then
    echo "  Package Service: iqq-package-service/coverage/index.html"
  fi
  
  if [ -d "iqq-lender-service/coverage" ]; then
    echo "  Lender Service: iqq-lender-service/coverage/index.html"
  fi
  
  if [ -d "iqq-product-service/coverage" ]; then
    echo "  Product Service: iqq-product-service/coverage/index.html"
  fi
  
  if [ -d "iqq-document-service/coverage" ]; then
    echo "  Document Service: iqq-document-service/coverage/index.html"
  fi
fi

# Print failed services if any
if [ $FAILED_SERVICES -gt 0 ]; then
  echo ""
  echo -e "${RED}Failed Services:${NC}"
  for service in "${FAILED_SERVICE_NAMES[@]}"; do
    echo "  - $service"
  done
fi

echo ""
print_header "Test Run Complete"

# Exit with appropriate code
if [ $FAILED_SERVICES -gt 0 ]; then
  echo -e "${RED}Some tests failed. Please review the output above.${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed successfully!${NC}"
  exit 0
fi
