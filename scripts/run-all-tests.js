#!/usr/bin/env node

/**
 * iQQ Test Runner - Node.js version
 * Executes all tests and aggregates results with detailed reporting
 * Usage: node scripts/run-all-tests.js [--coverage] [--verbose] [--json]
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
  coverage: args.includes('--coverage'),
  verbose: args.includes('--verbose'),
  json: args.includes('--json'),
  help: args.includes('--help')
};

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

// Show help
if (options.help) {
  console.log(`
iQQ Test Runner

Usage: node scripts/run-all-tests.js [OPTIONS]

Options:
  --coverage    Generate coverage reports
  --verbose     Show detailed test output
  --json        Output results in JSON format
  --help        Show this help message

Examples:
  node scripts/run-all-tests.js
  node scripts/run-all-tests.js --coverage
  node scripts/run-all-tests.js --coverage --json > test-results.json
  `);
  process.exit(0);
}

// Test results tracking
const results = {
  startTime: new Date(),
  services: [],
  summary: {
    total: 0,
    passed: 0,
    failed: 0,
    skipped: 0
  }
};

// Services to test
const services = [
  { name: 'Provider Services', path: 'iqq-providers' },
  { name: 'Package Service', path: 'iqq-package-service' },
  { name: 'Lender Service', path: 'iqq-lender-service' },
  { name: 'Product Service', path: 'iqq-product-service' },
  { name: 'Document Service', path: 'iqq-document-service' }
];

// Utility functions
function log(message, color = 'reset') {
  if (!options.json) {
    console.log(`${colors[color]}${message}${colors.reset}`);
  }
}

function printHeader(title) {
  if (!options.json) {
    console.log('');
    log('========================================', 'blue');
    log(title, 'blue');
    log('========================================', 'blue');
    console.log('');
  }
}

function checkDirectory(servicePath) {
  return fs.existsSync(servicePath);
}

function checkPackageJson(servicePath) {
  return fs.existsSync(path.join(servicePath, 'package.json'));
}

function installDependencies(servicePath) {
  const nodeModulesPath = path.join(servicePath, 'node_modules');
  
  if (!fs.existsSync(nodeModulesPath)) {
    log('  Installing dependencies...', 'yellow');
    try {
      execSync('npm install', {
        cwd: servicePath,
        stdio: options.verbose ? 'inherit' : 'pipe'
      });
      return true;
    } catch (error) {
      return false;
    }
  }
  return true;
}

function runTests(servicePath) {
  const testCommand = options.coverage ? 'npm run test:coverage' : 'npm test';
  
  try {
    execSync(testCommand, {
      cwd: servicePath,
      stdio: options.verbose ? 'inherit' : 'pipe',
      encoding: 'utf-8'
    });
    return { success: true, error: null };
  } catch (error) {
    return { 
      success: false, 
      error: error.message,
      stdout: error.stdout,
      stderr: error.stderr
    };
  }
}

function getCoverageStats(servicePath) {
  const coveragePath = path.join(servicePath, 'coverage', 'coverage-summary.json');
  
  if (fs.existsSync(coveragePath)) {
    try {
      const coverageData = JSON.parse(fs.readFileSync(coveragePath, 'utf-8'));
      const total = coverageData.total;
      
      return {
        lines: total.lines.pct,
        statements: total.statements.pct,
        functions: total.functions.pct,
        branches: total.branches.pct
      };
    } catch (error) {
      return null;
    }
  }
  
  return null;
}

function testService(service) {
  results.summary.total++;
  
  const serviceResult = {
    name: service.name,
    path: service.path,
    status: 'UNKNOWN',
    duration: 0,
    details: '',
    coverage: null
  };
  
  log(`Testing: ${service.name}`, 'yellow');
  log(`Path: ${service.path}`);
  
  const startTime = Date.now();
  
  // Check if directory exists
  if (!checkDirectory(service.path)) {
    log('✗ Directory not found', 'red');
    serviceResult.status = 'SKIPPED';
    serviceResult.details = 'Directory not found';
    results.summary.skipped++;
    results.services.push(serviceResult);
    console.log('');
    return;
  }
  
  // Check if package.json exists
  if (!checkPackageJson(service.path)) {
    log('✗ No package.json found', 'red');
    serviceResult.status = 'SKIPPED';
    serviceResult.details = 'No package.json';
    results.summary.skipped++;
    results.services.push(serviceResult);
    console.log('');
    return;
  }
  
  // Install dependencies if needed
  if (!installDependencies(service.path)) {
    log('✗ Failed to install dependencies', 'red');
    serviceResult.status = 'FAILED';
    serviceResult.details = 'Dependency installation failed';
    results.summary.failed++;
    results.services.push(serviceResult);
    console.log('');
    return;
  }
  
  // Run tests
  const testResult = runTests(service.path);
  const endTime = Date.now();
  serviceResult.duration = Math.round((endTime - startTime) / 1000);
  
  if (testResult.success) {
    log('✓ Tests passed', 'green');
    serviceResult.status = 'PASSED';
    serviceResult.details = 'All tests passed';
    results.summary.passed++;
    
    // Get coverage stats if available
    if (options.coverage) {
      serviceResult.coverage = getCoverageStats(service.path);
    }
  } else {
    log('✗ Tests failed', 'red');
    serviceResult.status = 'FAILED';
    serviceResult.details = 'Test execution failed';
    serviceResult.error = testResult.error;
    results.summary.failed++;
  }
  
  results.services.push(serviceResult);
  console.log('');
}

function printSummary() {
  if (options.json) {
    results.endTime = new Date();
    results.duration = Math.round((results.endTime - results.startTime) / 1000);
    console.log(JSON.stringify(results, null, 2));
    return;
  }
  
  printHeader('Test Results Summary');
  
  log('Service Results:', 'blue');
  console.log('');
  console.log('Service'.padEnd(30) + 'Status'.padEnd(12) + 'Duration'.padEnd(12) + 'Details');
  console.log('-'.repeat(80));
  
  results.services.forEach(service => {
    const statusColor = service.status === 'PASSED' ? 'green' : 
                       service.status === 'FAILED' ? 'red' : 'yellow';
    
    const line = service.name.padEnd(30) + 
                 service.status.padEnd(12) + 
                 `${service.duration}s`.padEnd(12) + 
                 service.details;
    
    log(line, statusColor);
    
    // Show coverage if available
    if (service.coverage) {
      const coverageLine = ''.padEnd(30) + 
                          `Coverage: Lines ${service.coverage.lines}% | ` +
                          `Statements ${service.coverage.statements}% | ` +
                          `Functions ${service.coverage.functions}% | ` +
                          `Branches ${service.coverage.branches}%`;
      log(coverageLine, 'cyan');
    }
  });
  
  console.log('');
  log('Statistics:', 'blue');
  console.log(`  Total Services: ${results.summary.total}`);
  log(`  Passed: ${results.summary.passed}`, 'green');
  log(`  Failed: ${results.summary.failed}`, 'red');
  log(`  Skipped: ${results.summary.skipped}`, 'yellow');
  
  const totalDuration = results.services.reduce((sum, s) => sum + s.duration, 0);
  console.log(`  Total Duration: ${totalDuration}s`);
  
  // Show coverage report locations
  if (options.coverage) {
    console.log('');
    log('Coverage Reports:', 'blue');
    results.services.forEach(service => {
      const coveragePath = path.join(service.path, 'coverage', 'index.html');
      if (fs.existsSync(coveragePath)) {
        console.log(`  ${service.name}: ${coveragePath}`);
      }
    });
  }
  
  // Show failed services
  const failedServices = results.services.filter(s => s.status === 'FAILED');
  if (failedServices.length > 0) {
    console.log('');
    log('Failed Services:', 'red');
    failedServices.forEach(service => {
      console.log(`  - ${service.name}`);
    });
  }
  
  console.log('');
  printHeader('Test Run Complete');
  
  if (results.summary.failed > 0) {
    log('Some tests failed. Please review the output above.', 'red');
  } else {
    log('All tests passed successfully!', 'green');
  }
}

// Main execution
function main() {
  printHeader('iQQ Test Suite Runner');
  
  if (!options.json) {
    console.log('Configuration:');
    console.log(`  Coverage: ${options.coverage}`);
    console.log(`  Verbose: ${options.verbose}`);
    console.log(`  JSON Output: ${options.json}`);
    console.log('');
  }
  
  printHeader('Running Tests');
  
  // Run tests for each service
  services.forEach(testService);
  
  // Print summary
  printSummary();
  
  // Exit with appropriate code
  process.exit(results.summary.failed > 0 ? 1 : 0);
}

// Run the script
main();
