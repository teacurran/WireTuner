#!/usr/bin/env node
/**
 * tools/test.cjs
 *
 * Cross-platform Flutter test execution script.
 * Ensures dependencies are installed before running tests.
 *
 * Usage: node tools/test.cjs [test-file-or-directory]
 * Exit codes: 0 = tests passed, 1 = tests failed or script error
 */

const { execSync, spawnSync } = require('child_process');
const path = require('path');

// Configuration
const PROJECT_ROOT = path.resolve(__dirname, '..');
const INSTALL_SCRIPT = path.join(__dirname, 'install.cjs');

/**
 * Run the install script to ensure dependencies are up-to-date
 * @returns {boolean} Success status
 */
function ensureDependencies() {
  console.error('[test] Ensuring dependencies are up-to-date...');
  try {
    execSync(`node "${INSTALL_SCRIPT}"`, {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      encoding: 'utf-8'
    });
    return true;
  } catch (error) {
    console.error('[test] Error: Failed to install dependencies');
    return false;
  }
}

/**
 * Run Flutter tests
 * @param {string|null} testPath - Optional specific test file or directory
 * @returns {boolean} Success status
 */
function runTests(testPath) {
  const args = ['test'];

  // Add specific test path if provided
  if (testPath) {
    args.push(testPath);
    console.error(`[test] Running tests in: ${testPath}`);
  } else {
    console.error('[test] Running all tests...');
  }

  // Add coverage reporting (optional, can be configured)
  // args.push('--coverage');

  try {
    const result = spawnSync('flutter', args, {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      encoding: 'utf-8',
      shell: process.platform === 'win32'
    });

    if (result.error) {
      console.error(`[test] Error: ${result.error.message}`);
      return false;
    }

    if (result.status !== 0) {
      console.error(`[test] Tests failed with exit code ${result.status}`);
      return false;
    }

    console.error('[test] All tests passed!');
    return true;
  } catch (error) {
    console.error(`[test] Error running tests: ${error.message}`);
    return false;
  }
}

/**
 * Main test execution process
 */
function main() {
  console.error('[test] Starting Flutter test runner...');

  // Step 1: Ensure dependencies are installed
  if (!ensureDependencies()) {
    console.error('[test] Aborted due to dependency installation failure');
    process.exit(1);
  }

  // Step 2: Get optional test path from command line arguments
  const testPath = process.argv[2] || null;

  // Step 3: Run tests
  const success = runTests(testPath);

  if (success) {
    console.error('[test] Test suite completed successfully');
    process.exit(0);
  } else {
    console.error('[test] Test suite failed');
    process.exit(1);
  }
}

// Execute main function
if (require.main === module) {
  main();
}

module.exports = { ensureDependencies, runTests };
