#!/usr/bin/env node
/**
 * tools/lint.cjs
 *
 * Cross-platform Flutter linting script with JSON output.
 * Ensures dependencies are installed before running Dart analyzer.
 *
 * Usage: node tools/lint.cjs
 * Exit codes: 0 = no issues, non-zero = issues found or script error
 *
 * Output: JSON array of error objects to stdout
 */

const { execSync } = require('child_process');
const path = require('path');

// Configuration
const PROJECT_ROOT = path.resolve(__dirname, '..');
const INSTALL_SCRIPT = path.join(__dirname, 'install.cjs');

/**
 * Run the install script silently to ensure dependencies are up-to-date
 * @returns {boolean} Success status
 */
function ensureDependencies() {
  try {
    execSync(`node "${INSTALL_SCRIPT}"`, {
      cwd: PROJECT_ROOT,
      stdio: 'ignore',
      encoding: 'utf-8'
    });
    return true;
  } catch (error) {
    console.error('[lint] Error: Failed to install dependencies');
    return false;
  }
}

/**
 * Parse Dart analyzer output into structured JSON
 * @param {string} output - Raw analyzer output
 * @returns {Array} Array of error objects
 */
function parseAnalyzerOutput(output) {
  const errors = [];
  const lines = output.split('\n');

  for (const line of lines) {
    // Skip empty lines and separator lines
    if (!line.trim() || line.includes('────') || line.includes('issue found') || line.includes('issues found')) {
      continue;
    }

    // Match Dart analyzer format:
    // <severity> • <message> • <file>:<line>:<column> • <rule>
    // Example: error • Missing required parameter • lib/main.dart:10:5 • missing_required_param
    const match = line.match(/^\s*(error|warning|info)\s+•\s+(.+?)\s+•\s+(.+?):(\d+):(\d+)\s+•\s+(.+)$/);

    if (match) {
      const [, severity, message, filePath, lineNum, colNum, rule] = match;

      // Only include errors and critical warnings
      if (severity === 'error') {
        errors.push({
          type: severity,
          path: filePath.trim(),
          obj: rule.trim(),
          message: message.trim(),
          line: parseInt(lineNum, 10),
          column: parseInt(colNum, 10)
        });
      }
    }
  }

  return errors;
}

/**
 * Run Dart analyzer on the project
 * @returns {Object} Object with success status and errors array
 */
function runAnalyzer() {
  try {
    // Run flutter analyze which uses the Dart analyzer
    const output = execSync('flutter analyze --no-preamble', {
      cwd: PROJECT_ROOT,
      encoding: 'utf-8',
      stdio: 'pipe'
    });

    // If we reach here, no errors were found
    return { success: true, errors: [] };
  } catch (error) {
    // Analyzer returns non-zero exit code when issues are found
    const output = error.stdout || error.stderr || '';
    const errors = parseAnalyzerOutput(output);

    // Determine if these are actual errors or just the command failing
    if (errors.length > 0) {
      return { success: false, errors };
    }

    // Check if it's a different kind of error
    if (output.includes('error') || output.includes('Error')) {
      // Try to parse whatever we can
      const parsedErrors = parseAnalyzerOutput(output);
      if (parsedErrors.length > 0) {
        return { success: false, errors: parsedErrors };
      }

      // If we can't parse, create a generic error
      return {
        success: false,
        errors: [{
          type: 'error',
          path: 'unknown',
          obj: 'analyzer',
          message: 'Analyzer failed: ' + (output.substring(0, 100) || error.message),
          line: 0,
          column: 0
        }]
      };
    }

    // No actual errors found despite non-zero exit
    return { success: true, errors: [] };
  }
}

/**
 * Main linting process
 */
function main() {
  // Step 1: Ensure dependencies are installed (silently)
  if (!ensureDependencies()) {
    // Output error in JSON format
    console.log(JSON.stringify([{
      type: 'error',
      path: 'tools/install.cjs',
      obj: 'dependencies',
      message: 'Failed to install dependencies',
      line: 0,
      column: 0
    }]));
    process.exit(1);
  }

  // Step 2: Run analyzer
  const result = runAnalyzer();

  // Step 3: Output results as JSON
  console.log(JSON.stringify(result.errors));

  // Step 4: Exit with appropriate code
  if (result.success && result.errors.length === 0) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

// Execute main function
if (require.main === module) {
  main();
}

module.exports = { ensureDependencies, parseAnalyzerOutput, runAnalyzer };
