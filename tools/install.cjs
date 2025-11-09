#!/usr/bin/env node
/**
 * tools/install.cjs
 *
 * Cross-platform Flutter/Dart environment setup and dependency installation script.
 * Supports both single-package Flutter projects and melos-managed monorepo workspaces.
 *
 * Usage: node tools/install.cjs
 * Exit codes: 0 = success, 1 = failure
 */

const { execSync, spawnSync } = require('child_process');
const { existsSync, readFileSync } = require('fs');
const path = require('path');

// Configuration
const PROJECT_ROOT = path.resolve(__dirname, '..');
const PUBSPEC_FILE = path.join(PROJECT_ROOT, 'pubspec.yaml');
const MELOS_CONFIG = path.join(PROJECT_ROOT, 'melos.yaml');

/**
 * Execute a command with proper error handling
 * @param {string} command - Command to execute
 * @param {Array<string>} args - Command arguments
 * @param {string} description - Description for logging
 * @param {Object} options - Additional spawn options
 * @returns {boolean} Success status
 */
function executeCommand(command, args, description, options = {}) {
  try {
    console.error(`[install] ${description}...`);
    const result = spawnSync(command, args, {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      encoding: 'utf-8',
      shell: process.platform === 'win32',
      ...options
    });

    if (result.error) {
      throw result.error;
    }

    if (result.status !== 0) {
      console.error(`[install] Error: ${description} failed with exit code ${result.status}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error(`[install] Error during ${description}: ${error.message}`);
    return false;
  }
}

/**
 * Check if a command is installed and accessible
 * @param {string} command - Command to check
 * @param {string} friendlyName - Human-readable name
 * @returns {boolean} True if command is available
 */
function checkCommandInstalled(command, friendlyName) {
  try {
    const result = spawnSync(command, ['--version'], {
      stdio: 'pipe',
      encoding: 'utf-8',
      shell: process.platform === 'win32'
    });

    if (result.error || result.status !== 0) {
      return false;
    }

    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Check if melos is installed globally
 * @returns {boolean} True if melos is available
 */
function checkMelosInstalled() {
  return checkCommandInstalled('melos', 'melos');
}

/**
 * Activate melos globally using dart pub global activate
 * @returns {boolean} Success status
 */
function activateMelos() {
  console.error('[install] Installing melos globally...');
  return executeCommand('dart', ['pub', 'global', 'activate', 'melos'], 'Activate melos globally');
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

  // Step 2: Check Flutter and Dart installation
  if (!checkCommandInstalled('flutter', 'Flutter')) {
    console.error('[install] Error: Flutter is not installed or not in PATH');
    console.error('[install] Please install Flutter from: https://flutter.dev/docs/get-started/install');
    process.exit(1);
  }

  if (!checkCommandInstalled('dart', 'Dart')) {
    console.error('[install] Error: Dart is not installed or not in PATH');
    console.error('[install] Dart should be installed with Flutter. Please check your Flutter installation.');
    process.exit(1);
  }

  console.error('[install] ✓ Flutter and Dart are installed');

  // Step 3: Check if this is a melos workspace
  const isMelosWorkspace = existsSync(MELOS_CONFIG);

  if (isMelosWorkspace) {
    console.error('[install] ✓ Melos workspace detected');

    // Step 4: Ensure melos is installed
    if (!checkMelosInstalled()) {
      console.error('[install] Melos not found globally, installing...');
      if (!activateMelos()) {
        console.error('[install] Failed to install melos');
        process.exit(1);
      }
    } else {
      console.error('[install] ✓ Melos is installed');
    }

    // Step 5: Bootstrap the melos workspace
    if (!executeCommand('melos', ['bootstrap'], 'Bootstrap melos workspace')) {
      console.error('[install] Failed to bootstrap workspace');
      process.exit(1);
    }

    // Step 6: Install dependencies in all packages
    if (!executeCommand('melos', ['run', 'get'], 'Install dependencies in all packages')) {
      console.error('[install] Failed to install dependencies');
      process.exit(1);
    }

    // Step 7: Run code generation if needed
    console.error('[install] Checking for code generation requirements...');
    try {
      const pubspecContent = readFileSync(PUBSPEC_FILE, 'utf-8');
      const needsCodeGen = pubspecContent.includes('build_runner:') ||
                           pubspecContent.includes('freezed:') ||
                           pubspecContent.includes('json_serializable:');

      if (needsCodeGen) {
        console.error('[install] Code generation dependencies detected, running build_runner...');
        const codeGenResult = executeCommand('melos', ['run', 'build:runner'],
          'Run code generation across workspace', { stdio: 'pipe' });

        if (!codeGenResult) {
          console.error('[install] Warning: Code generation encountered issues (may be expected if no annotations present)');
        } else {
          console.error('[install] ✓ Code generation completed successfully');
        }
      }
    } catch (error) {
      console.error('[install] Warning: Could not check for code generation requirements');
    }

  } else {
    // Single-package mode
    console.error('[install] ✓ Single-package Flutter project detected');

    // Step 4: Get Flutter dependencies
    if (!executeCommand('flutter', ['pub', 'get'], 'Installing Flutter dependencies')) {
      console.error('[install] Failed to install dependencies');
      process.exit(1);
    }

    // Step 5: Run code generation if build_runner is present
    console.error('[install] Checking for code generation requirements...');
    try {
      const pubspecContent = readFileSync(PUBSPEC_FILE, 'utf-8');
      const needsCodeGen = pubspecContent.includes('build_runner:') ||
                           pubspecContent.includes('freezed:') ||
                           pubspecContent.includes('json_serializable:');

      if (needsCodeGen) {
        console.error('[install] Code generation dependencies detected, running build_runner...');
        const codeGenResult = executeCommand('flutter',
          ['pub', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'],
          'Run code generation', { stdio: 'pipe' });

        if (!codeGenResult) {
          console.error('[install] Warning: Code generation encountered issues (may be expected if no annotations present)');
        } else {
          console.error('[install] ✓ Code generation completed successfully');
        }
      } else {
        console.error('[install] No code generation dependencies found, skipping');
      }
    } catch (error) {
      console.error('[install] Warning: Could not check for code generation requirements');
    }
  }

  console.error('[install] ✓ Environment setup completed successfully!');
  console.error('[install] All dependencies are installed and up-to-date.');
  process.exit(0);
}

// Execute main function
if (require.main === module) {
  main();
}

module.exports = { executeCommand, checkCommandInstalled, checkMelosInstalled, activateMelos };
