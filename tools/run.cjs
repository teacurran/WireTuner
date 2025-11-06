#!/usr/bin/env node
/**
 * tools/run.cjs
 *
 * Cross-platform Flutter application execution script.
 * Ensures environment is set up before running the Flutter application.
 *
 * Usage: node tools/run.cjs [device-id]
 * Exit codes: 0 = success, 1 = failure
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
  console.error('[run] Ensuring dependencies are up-to-date...');
  try {
    execSync(`node "${INSTALL_SCRIPT}"`, {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      encoding: 'utf-8'
    });
    return true;
  } catch (error) {
    console.error('[run] Error: Failed to install dependencies');
    return false;
  }
}

/**
 * Detect the platform and determine appropriate device
 * @returns {string|null} Device argument or null for default
 */
function detectPlatform() {
  const platform = process.platform;

  // Try to detect available devices
  try {
    const devicesOutput = execSync('flutter devices', {
      cwd: PROJECT_ROOT,
      encoding: 'utf-8',
      stdio: 'pipe'
    });

    console.error('[run] Available devices:');
    console.error(devicesOutput);

    // For macOS, prefer macOS as the device
    if (platform === 'darwin' && devicesOutput.includes('macos')) {
      return 'macos';
    }

    // For Windows, prefer Windows as the device
    if (platform === 'win32' && devicesOutput.includes('windows')) {
      return 'windows';
    }

    // For Linux, prefer Linux as the device
    if (platform === 'linux' && devicesOutput.includes('linux')) {
      return 'linux';
    }
  } catch (error) {
    console.error('[run] Warning: Could not detect devices, using default');
  }

  return null;
}

/**
 * Run the Flutter application
 * @param {string|null} device - Target device ID
 * @returns {boolean} Success status
 */
function runApplication(device) {
  const args = ['run'];

  // Add device argument if specified
  if (device) {
    args.push('-d', device);
  }

  // Check for command line argument
  const userDevice = process.argv[2];
  if (userDevice) {
    args.push('-d', userDevice);
    console.error(`[run] Running on device: ${userDevice}`);
  } else if (device) {
    console.error(`[run] Running on detected device: ${device}`);
  } else {
    console.error('[run] Running on default device');
  }

  console.error('[run] Starting Flutter application...');
  console.error('[run] Press Ctrl+C to stop the application');

  try {
    const result = spawnSync('flutter', args, {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      encoding: 'utf-8',
      shell: process.platform === 'win32'
    });

    if (result.error) {
      console.error(`[run] Error: ${result.error.message}`);
      return false;
    }

    if (result.status !== 0) {
      console.error(`[run] Application exited with code ${result.status}`);
      return false;
    }

    return true;
  } catch (error) {
    console.error(`[run] Error running application: ${error.message}`);
    return false;
  }
}

/**
 * Main execution process
 */
function main() {
  console.error('[run] Starting Flutter application runner...');

  // Step 1: Ensure dependencies are installed
  if (!ensureDependencies()) {
    console.error('[run] Aborted due to dependency installation failure');
    process.exit(1);
  }

  // Step 2: Detect target platform/device
  const device = detectPlatform();

  // Step 3: Run the application
  const success = runApplication(device);

  if (success) {
    console.error('[run] Application exited successfully');
    process.exit(0);
  } else {
    console.error('[run] Application failed to run');
    process.exit(1);
  }
}

// Execute main function
if (require.main === module) {
  main();
}

module.exports = { ensureDependencies, detectPlatform, runApplication };
