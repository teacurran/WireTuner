#!/usr/bin/env node
/**
 * tools/install.cjs
 *
 * Cross-platform Flutter environment setup and dependency installation script.
 * This script ensures Flutter dependencies are installed and up-to-date.
 *
 * Usage: node tools/install.cjs
 * Exit codes: 0 = success, 1 = failure
 */

const { execSync } = require('child_process');
const { existsSync } = require('fs');
const path = require('path');

// Configuration
const PROJECT_ROOT = path.resolve(__dirname, '..');
const PUBSPEC_FILE = path.join(PROJECT_ROOT, 'pubspec.yaml');
const PUBSPEC_LOCK = path.join(PROJECT_ROOT, 'pubspec.lock');

/**
 * Execute a command with proper error handling
 * @param {string} command - Command to execute
 * @param {string} description - Description for logging
 * @returns {boolean} Success status
 */
function executeCommand(command, description) {
  try {
    console.error(`[install] ${description}...`);
    execSync(command, {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      encoding: 'utf-8'
    });
    return true;
  } catch (error) {
    console.error(`[install] Error during ${description}: ${error.message}`);
    return false;
  }
}

/**
 * Check if Flutter is installed and accessible
 * @returns {boolean} True if Flutter is available
 */
function checkFlutterInstalled() {
  try {
    execSync('flutter --version', {
      stdio: 'pipe',
      encoding: 'utf-8'
    });
    return true;
  } catch (error) {
    console.error('[install] Error: Flutter is not installed or not in PATH');
    console.error('[install] Please install Flutter from: https://flutter.dev/docs/get-started/install');
    return false;
  }
}

/**
 * Main installation process
 */
function main() {
  console.error('[install] Starting Flutter environment setup...');

  // Step 1: Verify pubspec.yaml exists
  if (!existsSync(PUBSPEC_FILE)) {
    console.error(`[install] Error: pubspec.yaml not found at ${PUBSPEC_FILE}`);
    process.exit(1);
  }

  // Step 2: Check Flutter installation
  if (!checkFlutterInstalled()) {
    process.exit(1);
  }

  // Step 3: Check Flutter doctor status (informational)
  console.error('[install] Checking Flutter environment...');
  try {
    execSync('flutter doctor', {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      encoding: 'utf-8'
    });
  } catch (error) {
    console.error('[install] Warning: Flutter doctor reported issues. Continuing with installation...');
  }

  // Step 4: Get Flutter dependencies
  if (!executeCommand('flutter pub get', 'Installing Flutter dependencies')) {
    console.error('[install] Failed to install dependencies');
    process.exit(1);
  }

  // Step 5: Verify lock file was created/updated
  if (!existsSync(PUBSPEC_LOCK)) {
    console.error('[install] Warning: pubspec.lock was not created');
  }

  // Step 6: Run code generation if build_runner is present
  console.error('[install] Checking for code generation requirements...');
  const { readFileSync } = require('fs');
  try {
    const pubspecContent = readFileSync(PUBSPEC_FILE, 'utf-8');
    const needsCodeGen = pubspecContent.includes('build_runner:') ||
                         pubspecContent.includes('freezed:') ||
                         pubspecContent.includes('json_serializable:');

    if (needsCodeGen) {
      console.error('[install] Code generation dependencies detected, running build_runner...');
      try {
        execSync('flutter pub run build_runner build --delete-conflicting-outputs', {
          cwd: PROJECT_ROOT,
          stdio: 'inherit',
          encoding: 'utf-8'
        });
        console.error('[install] Code generation completed successfully');
      } catch (genError) {
        console.error('[install] Warning: Code generation encountered issues (may be expected if no annotations present)');
        // Don't fail the installation if code generation fails
      }
    } else {
      console.error('[install] No code generation dependencies found, skipping');
    }
  } catch (error) {
    console.error('[install] Warning: Could not check for code generation requirements');
  }

  console.error('[install] Environment setup completed successfully!');
  console.error('[install] All dependencies are installed and up-to-date.');
  process.exit(0);
}

// Execute main function
if (require.main === module) {
  main();
}

module.exports = { executeCommand, checkFlutterInstalled };
